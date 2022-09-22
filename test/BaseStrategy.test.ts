import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("BaseStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestBaseStrategy: any;
  let StrategyFactory: any;
  let TestProtocol: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let factory: any;
  let strategy: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let protocol: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    StrategyFactory = await ethers.getContractFactory("TestStrategyFactory");
    TestBaseStrategy = await ethers.getContractFactory("TestBaseStrategy");
    TestProtocol = await ethers.getContractFactory("TestProtocol");
    [owner, addr1, addr2] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    protocol = await TestProtocol.deploy(
      addr1.address,
      addr2.address,
      PROTOCOL_ID
    );
    factory = await StrategyFactory.deploy(
      cfmm.address,
      PROTOCOL_ID,
      [tokenA.address, tokenB.address],
      protocol.address
    );

    await (await factory.createBaseStrategy()).wait();
    const strategyAddr = await factory.strategy();

    strategy = await TestBaseStrategy.attach(
      strategyAddr // The deployed contract address
    );
  });

  async function depositInCFMM(amount0: any, amount1: any) {
    const balanceA = await tokenA.balanceOf(cfmm.address);
    const balanceB = await tokenB.balanceOf(cfmm.address);

    await (await tokenA.transfer(cfmm.address, amount0)).wait();
    await (await tokenB.transfer(cfmm.address, amount1)).wait();
    expect(await cfmm.reserves0()).to.equal(balanceA);
    expect(await cfmm.reserves1()).to.equal(balanceB);

    await (await cfmm.sync()).wait();
    expect(await cfmm.reserves0()).to.equal(balanceA.add(amount0));
    expect(await cfmm.reserves1()).to.equal(balanceB.add(amount1));
  }

  function getCFMMIndex(
    lastCFMMInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    prevCFMMInvariant: BigNumber,
    prevCFMMTotalSupply: BigNumber
  ): BigNumber {
    const ONE = ethers.BigNumber.from(10).pow(18);
    const denominator = prevCFMMInvariant.mul(lastCFMMTotalSupply).div(ONE);
    return lastCFMMInvariant.mul(prevCFMMTotalSupply).div(denominator);
  }

  async function checkCFMMData(
    strategy: any,
    CFMMFeeIndex: BigNumber,
    CFMMInvariant: BigNumber,
    CFMMTotalSupply: BigNumber
  ) {
    await (await strategy.testUpdateCFMMIndex()).wait();
    const cfmmData = await strategy.getCFMMData();
    expect(cfmmData.lastCFMMFeeIndex).to.equal(CFMMFeeIndex);
    expect(cfmmData.lastCFMMInvariant).to.equal(CFMMInvariant);
    expect(cfmmData.lastCFMMTotalSupply).to.equal(CFMMTotalSupply);
  }

  function calcFeeIndex(
    blockNumber: BigNumber,
    lastBlockNumber: BigNumber,
    borrowRate: BigNumber,
    cfmmFeeIndex: BigNumber
  ): BigNumber {
    const blockDiff = blockNumber.sub(lastBlockNumber);
    const adjBorrowRate = blockDiff.mul(borrowRate).div(2252571);
    return cfmmFeeIndex.add(adjBorrowRate);
  }

  async function testFeeIndex(cfmmIndex: BigNumber, borrowRate: BigNumber) {
    await (await strategy.setBorrowRate(borrowRate)).wait();
    await (await strategy.setCFMMIndex(cfmmIndex)).wait();
    await (await strategy.testUpdateFeeIndex()).wait();
    const lastFeeIndex = await strategy.getLastFeeIndex();
    const lastBlockNumber = await strategy.getLastBlockNumber();
    const latestBlock = await ethers.provider.getBlock("latest");
    const expFeeIndex = calcFeeIndex(
      BigNumber.from(latestBlock.number),
      lastBlockNumber,
      borrowRate,
      cfmmIndex
    );
    expect(lastFeeIndex).to.equal(expFeeIndex);
  }

  async function testFeeIndexCases(num: BigNumber) {
    await testFeeIndex(num, num);
    await testFeeIndex(num, num.mul(2));
    await testFeeIndex(num.mul(2), num);
    await testFeeIndex(num.mul(2), num.mul(3));
  }

  function updateBorrowedInvariant(
    borrowedInvariant: BigNumber,
    lastFeeIndex: BigNumber
  ): BigNumber {
    const ONE = ethers.BigNumber.from(10).pow(18);
    return borrowedInvariant.mul(lastFeeIndex).div(ONE);
  }

  function calcLPTokenBorrowedPlusInterest(
    borrowedInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    lastCFMMInvariant: BigNumber
  ): BigNumber {
    if (lastCFMMInvariant.eq(0)) {
      return BigNumber.from(0);
    }
    return borrowedInvariant.mul(lastCFMMTotalSupply).div(lastCFMMInvariant);
  }

  function calcLPInvariant(
    lpTokenBalance: BigNumber,
    lastCFMMInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber
  ): BigNumber {
    if (lastCFMMTotalSupply.eq(0)) {
      return BigNumber.from(0);
    }
    return lpTokenBalance.mul(lastCFMMInvariant).div(lastCFMMTotalSupply);
  }

  function calcLPTokenTotal(
    lpTokenBalance: BigNumber,
    lpTokenBorrowedPlusInterest: BigNumber
  ): BigNumber {
    return lpTokenBalance.add(lpTokenBorrowedPlusInterest);
  }

  function calcTotalInvariant(
    lpInvariant: BigNumber,
    borrowedInvariant: BigNumber
  ): BigNumber {
    return lpInvariant.add(borrowedInvariant);
  }

  function updateAccFeeIndex(
    accFeeIndex: BigNumber,
    lastFeeIndex: BigNumber
  ): BigNumber {
    const ONE = ethers.BigNumber.from(10).pow(18);
    return accFeeIndex.mul(lastFeeIndex).div(ONE);
  }

  async function checkUpdateStore(
    strategy: any,
    accFeeIndex: BigNumber,
    lastFeeIndex: BigNumber,
    lpTokenBalance: BigNumber,
    borrowedInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    lastCFMMInvariant: BigNumber
  ) {
    const expBorrowedInvariant = updateBorrowedInvariant(
      borrowedInvariant,
      lastFeeIndex
    );
    const expLpTokenBorrowedPlusInterest = calcLPTokenBorrowedPlusInterest(
      expBorrowedInvariant,
      lastCFMMTotalSupply,
      lastCFMMInvariant
    );
    const expLPInvariant = calcLPInvariant(
      lpTokenBalance,
      lastCFMMInvariant,
      lastCFMMTotalSupply
    );
    const expLPTokenTotal = calcLPTokenTotal(
      lpTokenBalance,
      expLpTokenBorrowedPlusInterest
    );
    const expTotalInvariant = calcTotalInvariant(
      expLPInvariant,
      expBorrowedInvariant
    );
    const expAccFeeIndex = updateAccFeeIndex(accFeeIndex, lastFeeIndex);
    const latestBlock = await ethers.provider.getBlock("latest");
    const expBlockNumber = BigNumber.from(latestBlock.number);
    const storeFields = await strategy.getUpdateStoreFields();

    expect(storeFields.borrowedInvariant).to.equal(expBorrowedInvariant);
    expect(storeFields.accFeeIndex).to.equal(expAccFeeIndex);
    expect(storeFields.lpInvariant).to.equal(expLPInvariant);
    expect(storeFields.lpTokenTotal).to.equal(expLPTokenTotal);
    expect(storeFields.totalInvariant).to.equal(expTotalInvariant);
    expect(storeFields.lastBlockNumber).to.equal(expBlockNumber);
  }

  async function testUpdateStore(
    strategy: any,
    accFeeIndex: BigNumber,
    lastFeeIndex: BigNumber,
    lpTokenBalance: BigNumber,
    borrowedInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    lastCFMMInvariant: BigNumber
  ) {
    await (
      await strategy.setUpdateStoreFields(
        accFeeIndex,
        lastFeeIndex,
        lpTokenBalance,
        borrowedInvariant,
        lastCFMMTotalSupply,
        lastCFMMInvariant
      )
    ).wait();
    await (await strategy.testUpdateStore()).wait();
    await checkUpdateStore(
      strategy,
      accFeeIndex,
      lastFeeIndex,
      lpTokenBalance,
      borrowedInvariant,
      lastCFMMTotalSupply,
      lastCFMMInvariant
    );
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set right init params", async function () {
      const params = await strategy.getParameters();
      expect(params.factory).to.equal(factory.address);
      expect(params.cfmm).to.equal(cfmm.address);
      expect(params.tokens[0]).to.equal(tokenA.address);
      expect(params.tokens[1]).to.equal(tokenB.address);
      expect(params.protocolId).to.equal(PROTOCOL_ID);
      expect(params.protocol).to.equal(protocol.address);

      const cfmmData = await strategy.getCFMMData();
      const ONE = ethers.BigNumber.from(10).pow(18);
      expect(cfmmData.lastCFMMFeeIndex).to.equal(ONE);
      expect(cfmmData.lastCFMMInvariant).to.equal(0);
      expect(cfmmData.lastCFMMTotalSupply).to.equal(0);

      expect(await strategy.invariant()).to.equal(0);
      await (await strategy.setInvariant(100000)).wait();
      expect(await strategy.invariant()).to.equal(100000);

      expect(await strategy.getCFMMIndex()).to.equal(ONE);
      await (await strategy.setCFMMIndex(ONE.mul(2))).wait();
      expect(await strategy.getCFMMIndex()).to.equal(ONE.mul(2));

      expect(await strategy.borrowRate()).to.equal(ONE);
      await (await strategy.setBorrowRate(ONE.mul(2))).wait();
      expect(await strategy.borrowRate()).to.equal(ONE.mul(2));

      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);
      const lastBlockNumber = await strategy.getLastBlockNumber();
      const latestBlock = await ethers.provider.getBlock("latest");

      expect(lastBlockNumber).to.lt(BigNumber.from(latestBlock.number));

      await (await strategy.updateLastBlockNumber()).wait();
      const latestBlock0 = await ethers.provider.getBlock("latest");
      const lastBlockNumber0 = await strategy.getLastBlockNumber();
      expect(lastBlockNumber0).to.equal(BigNumber.from(latestBlock0.number));

      await (
        await strategy.setUpdateStoreFields(10, 20, 30, 40, 50, 60)
      ).wait();
      const storeFields = await strategy.getUpdateStoreFields();
      expect(storeFields.accFeeIndex).to.equal(10);
      expect(storeFields.lastFeeIndex).to.equal(20);
      expect(storeFields.lpTokenBalance).to.equal(30);
      expect(storeFields.borrowedInvariant).to.equal(40);
      expect(storeFields.lastCFMMTotalSupply).to.equal(50);
      expect(storeFields.lastCFMMInvariant).to.equal(60);
    });

    it("Update reserves", async function () {
      await depositInCFMM(1000, 2000);
      const reserves = await strategy.getReserves();
      await (await strategy.testUpdateReserves()).wait();
      const _reserves = await strategy.getReserves();
      expect(_reserves[0]).to.equal(reserves[0].add(1000));
      expect(_reserves[1]).to.equal(reserves[1].add(2000));
    });

    it("Mint & Burn shares", async function () {
      const balance = await cfmm.balanceOf(owner.address);
      const totalSupply = await cfmm.totalSupply();
      await (await cfmm.mint(100, owner.address)).wait();
      expect(await cfmm.balanceOf(owner.address)).to.equal(balance.add(100));
      expect(await cfmm.totalSupply()).to.equal(totalSupply.add(100));

      await (await cfmm.burn(100, owner.address)).wait();
      expect(await cfmm.balanceOf(owner.address)).to.equal(balance);
      expect(await cfmm.totalSupply()).to.equal(totalSupply);
    });
  });

  describe("Mint & Burn", function () {
    it("Mint", async function () {
      const balance = await strategy.balanceOf(owner.address);
      expect(balance).to.equal(0);
      expect(await strategy.totalSupply()).to.equal(0);

      await (await strategy.testMint(owner.address, 100)).wait();

      expect(await strategy.balanceOf(owner.address)).to.equal(
        balance.add(100)
      );
      expect(await strategy.totalSupply()).to.equal(100);

      await expect(strategy.testMint(owner.address, 0)).to.be.revertedWith(
        "0 amt"
      );
      expect(await strategy.totalSupply()).to.equal(100);
    });

    it("Burn", async function () {
      await (await strategy.testMint(owner.address, 100)).wait();
      const balance = await strategy.balanceOf(owner.address);
      expect(balance).to.equal(100);
      expect(await strategy.totalSupply()).to.equal(100);

      await expect(
        strategy.testBurn(ethers.constants.AddressZero, 10)
      ).to.be.revertedWith("0 address");

      await expect(strategy.testBurn(owner.address, 101)).to.be.revertedWith(
        "> balance"
      );
      await expect(strategy.testBurn(addr1.address, 1)).to.be.revertedWith(
        "> balance"
      );
      expect(await strategy.totalSupply()).to.equal(100);

      await (await strategy.testBurn(owner.address, 10)).wait();
      expect(await strategy.balanceOf(owner.address)).to.equal(90);
      expect(await strategy.totalSupply()).to.equal(90);

      await (await strategy.testBurn(owner.address, 90)).wait();
      expect(await strategy.balanceOf(owner.address)).to.equal(0);
      expect(await strategy.totalSupply()).to.equal(0);
    });
  });

  describe("Update Index", function () {
    it("Update CFMM Index, last = 0, prev = 0 => idx = 1, prev = 0", async function () {
      const cfmmData = await strategy.getCFMMData();
      const ONE = ethers.BigNumber.from(10).pow(18);
      const prevCFMMInvariant = cfmmData.lastCFMMInvariant;
      const prevCFMMTotalSupply = cfmmData.lastCFMMTotalSupply;
      const prevCFMMFeeIndex = cfmmData.lastCFMMFeeIndex;

      const cfmmTotalSupply = await cfmm.totalSupply();
      const cfmmInvariant = await strategy.invariant();

      expect(prevCFMMFeeIndex).to.equal(ONE);
      expect(prevCFMMTotalSupply).to.equal(0);
      expect(prevCFMMInvariant).to.equal(0);
      expect(cfmmTotalSupply).to.equal(0);
      expect(cfmmInvariant).to.equal(0);
      // last = 0, prev = 0 => idx = 1, prev = 0
      // both 0
      await checkCFMMData(strategy, ONE, cfmmInvariant, cfmmTotalSupply);

      // only last.supp is 0
      const newInvariant = ONE.mul(100);
      await (await strategy.setInvariant(newInvariant)).wait();
      const cfmmInvariant0 = await strategy.invariant(); // 100
      const cfmmTotalSupply0 = await cfmm.totalSupply(); // 0
      expect(cfmmInvariant0).to.equal(newInvariant);
      expect(cfmmTotalSupply0).to.equal(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant0, cfmmTotalSupply0);

      // reset
      await (await strategy.setInvariant(0)).wait();
      const cfmmInvariant1 = await strategy.invariant(); // 0
      const cfmmTotalSupply1 = await cfmm.totalSupply(); // 0
      expect(cfmmInvariant1).to.equal(0);
      expect(cfmmTotalSupply1).to.equal(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant1, cfmmTotalSupply1);

      // only last.inv is 0
      const newSupply = ONE.mul(100);
      await (await cfmm.mint(newSupply, owner.address)).wait();
      const cfmmInvariant2 = await strategy.invariant(); // 0
      const cfmmTotalSupply2 = await cfmm.totalSupply(); // 0
      expect(cfmmInvariant2).to.equal(0);
      expect(cfmmTotalSupply2).to.equal(newSupply);
      await checkCFMMData(strategy, ONE, cfmmInvariant2, cfmmTotalSupply2);
    });

    it("Update CFMM Index, last > 0, prev = 0 => idx = 1, prev = last", async function () {
      // last > 0, prev = 0 => idx = 1, prev = last
      const cfmmData = await strategy.getCFMMData();
      const ONE = ethers.BigNumber.from(10).pow(18);
      const prevCFMMInvariant = cfmmData.lastCFMMInvariant;
      const prevCFMMTotalSupply = cfmmData.lastCFMMTotalSupply;
      const prevCFMMFeeIndex = cfmmData.lastCFMMFeeIndex;

      expect(prevCFMMFeeIndex).to.equal(ONE);
      expect(prevCFMMTotalSupply).to.equal(0);
      expect(prevCFMMInvariant).to.equal(0);

      const newSupply = ONE.mul(100);
      const newInvariant = ONE.mul(200);
      await (await cfmm.mint(newSupply, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant)).wait();
      const cfmmTotalSupply = await cfmm.totalSupply();
      const cfmmInvariant = await strategy.invariant();
      expect(cfmmTotalSupply).to.equal(newSupply);
      expect(cfmmInvariant).to.equal(newInvariant);
      await checkCFMMData(strategy, ONE, cfmmInvariant, cfmmTotalSupply);
    });

    it("Update CFMM Index, last > 0, prev > 0 => idx > 1, prev = last", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      const newSupply = ONE.mul(100);
      const newInvariant = ONE.mul(200);

      // last > 0, prev > 0 => idx > 1, prev = last
      await (await cfmm.mint(newSupply, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(3))).wait();
      const cfmmTotalSupplyX = await cfmm.totalSupply();
      const cfmmInvariantX = await strategy.invariant();
      expect(cfmmTotalSupplyX).to.equal(newSupply);
      expect(cfmmInvariantX).to.equal(newInvariant.mul(3));

      await (await strategy.testUpdateCFMMIndex()).wait();
      await (await cfmm.mint(newSupply, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(6))).wait();
      const cfmmTotalSupply0 = await cfmm.totalSupply();
      const cfmmInvariant0 = await strategy.invariant();
      expect(cfmmTotalSupply0).to.equal(newSupply.mul(2));
      expect(cfmmInvariant0).to.equal(newInvariant.mul(6));

      const cfmmData0 = await strategy.getCFMMData();
      const prevCFMMInvariant0 = cfmmData0.lastCFMMInvariant;
      const prevCFMMTotalSupply0 = cfmmData0.lastCFMMTotalSupply;
      expect(prevCFMMInvariant0).to.gt(0);
      expect(prevCFMMTotalSupply0).to.gt(0);
      const cfmmIndex = getCFMMIndex(
        cfmmInvariant0,
        cfmmTotalSupply0,
        prevCFMMInvariant0,
        prevCFMMTotalSupply0
      );

      await checkCFMMData(
        strategy,
        cfmmIndex,
        cfmmInvariant0,
        cfmmTotalSupply0
      );

      // last = 0, prev > 0 => idx = 1, prev = 0
      // both 0
      await (await cfmm.burn(cfmmTotalSupply0, owner.address)).wait();
      await (await strategy.setInvariant(0)).wait();
      const cfmmTotalSupply1 = await cfmm.totalSupply();
      const cfmmInvariant1 = await strategy.invariant();
      expect(cfmmTotalSupply1).to.equal(0);
      expect(cfmmInvariant1).to.equal(0);
      const cfmmData1 = await strategy.getCFMMData();
      const prevCFMMInvariant1 = cfmmData1.lastCFMMInvariant;
      const prevCFMMTotalSupply1 = cfmmData1.lastCFMMTotalSupply;
      const prevCFMMFeeIndex1 = cfmmData1.lastCFMMFeeIndex;
      expect(prevCFMMInvariant1).to.gt(0);
      expect(prevCFMMTotalSupply1).to.gt(0);
      expect(prevCFMMFeeIndex1).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant1, cfmmTotalSupply1);

      // only supp becomes 0
      await (await cfmm.mint(cfmmTotalSupply0, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(4))).wait();
      const cfmmTotalSupply2 = await cfmm.totalSupply();
      const cfmmInvariant2 = await strategy.invariant();
      expect(cfmmTotalSupply2).to.gt(0);
      expect(cfmmInvariant2).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant2, cfmmTotalSupply2);
      await (await strategy.setCFMMIndex(ONE.mul(4))).wait();
      const cfmmData2 = await strategy.getCFMMData();
      const prevCFMMInvariant2 = cfmmData2.lastCFMMInvariant;
      const prevCFMMTotalSupply2 = cfmmData2.lastCFMMTotalSupply;
      const prevCFMMFeeIndex2 = cfmmData2.lastCFMMFeeIndex;
      expect(prevCFMMInvariant2).to.gt(0);
      expect(prevCFMMTotalSupply2).to.gt(0);
      expect(prevCFMMFeeIndex2).to.equal(ONE.mul(4));

      await (await cfmm.burn(cfmmTotalSupply2, owner.address)).wait();
      const cfmmTotalSupply_ = await cfmm.totalSupply();
      const cfmmInvariant_ = await strategy.invariant();
      expect(cfmmTotalSupply_).to.equal(0);
      expect(cfmmInvariant_).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant_, cfmmTotalSupply_);

      // only inv becomes 0
      await (await cfmm.mint(cfmmTotalSupply0, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(5))).wait();
      const cfmmTotalSupply3 = await cfmm.totalSupply();
      const cfmmInvariant3 = await strategy.invariant();
      expect(cfmmTotalSupply3).to.gt(0);
      expect(cfmmInvariant3).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant3, cfmmTotalSupply3);
      await (await strategy.setCFMMIndex(ONE.mul(3))).wait();
      const cfmmData3 = await strategy.getCFMMData();
      const prevCFMMInvariant3 = cfmmData3.lastCFMMInvariant;
      const prevCFMMTotalSupply3 = cfmmData3.lastCFMMTotalSupply;
      const prevCFMMFeeIndex3 = cfmmData3.lastCFMMFeeIndex;
      expect(prevCFMMInvariant3).to.gt(0);
      expect(prevCFMMTotalSupply3).to.gt(0);
      expect(prevCFMMFeeIndex3).to.equal(ONE.mul(3));

      await (await strategy.setInvariant(0)).wait();
      const cfmmTotalSupply0_ = await cfmm.totalSupply();
      const cfmmInvariant0_ = await strategy.invariant();
      expect(cfmmTotalSupply0_).to.gt(0);
      expect(cfmmInvariant0_).to.equal(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant0_, cfmmTotalSupply0_);
    });

    it("Update Fee Index", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));

      // mine 1000 blocks with an interval of 1 minute
      await ethers.provider.send("hardhat_mine", ["0x3e8", "0x3c"]);

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));

      await (await strategy.updateLastBlockNumber()).wait();

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));

      // mine 1000 blocks with an interval of 1 minute
      await ethers.provider.send("hardhat_mine", ["0xaf9", "0xa3c"]);

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));
    });

    it("Update Store", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      const accFeeIndex = ONE.mul(10);
      const lastFeeIndex = ONE.mul(20);
      const lpTokenBalance = ONE.mul(30);
      const borrowedInvariant = ONE.mul(40);
      const lastCFMMTotalSupply = ONE.mul(50);
      const lastCFMMInvariant = ONE.mul(60);
      await testUpdateStore(
        strategy,
        accFeeIndex,
        lastFeeIndex,
        lpTokenBalance,
        borrowedInvariant,
        lastCFMMTotalSupply,
        lastCFMMInvariant
      );

      const accFeeIndex0 = ONE.mul(10);
      const lastFeeIndex0 = ONE.mul(20);
      const lpTokenBalance0 = ONE.mul(30);
      const borrowedInvariant0 = ONE.mul(40);
      const lastCFMMTotalSupply0 = ONE.mul(0);
      const lastCFMMInvariant0 = ONE.mul(60);
      await testUpdateStore(
        strategy,
        accFeeIndex0,
        lastFeeIndex0,
        lpTokenBalance0,
        borrowedInvariant0,
        lastCFMMTotalSupply0,
        lastCFMMInvariant0
      );

      const accFeeIndex1 = ONE.mul(10);
      const lastFeeIndex1 = ONE.mul(20);
      const lpTokenBalance1 = ONE.mul(30);
      const borrowedInvariant1 = ONE.mul(40);
      const lastCFMMTotalSupply1 = ONE.mul(50);
      const lastCFMMInvariant1 = ONE.mul(0);
      await testUpdateStore(
        strategy,
        accFeeIndex1,
        lastFeeIndex1,
        lpTokenBalance1,
        borrowedInvariant1,
        lastCFMMTotalSupply1,
        lastCFMMInvariant1
      );

      const accFeeIndex2 = ONE.mul(10);
      const lastFeeIndex2 = ONE.mul(20);
      const lpTokenBalance2 = ONE.mul(30);
      const borrowedInvariant2 = ONE.mul(40);
      const lastCFMMTotalSupply2 = ONE.mul(0);
      const lastCFMMInvariant2 = ONE.mul(0);
      await testUpdateStore(
        strategy,
        accFeeIndex2,
        lastFeeIndex2,
        lpTokenBalance2,
        borrowedInvariant2,
        lastCFMMTotalSupply2,
        lastCFMMInvariant2
      );

      const accFeeIndex3 = ONE.mul(103);
      const lastFeeIndex3 = ONE.mul(204);
      const lpTokenBalance3 = ONE.mul(320);
      const borrowedInvariant3 = ONE.mul(430);
      const lastCFMMTotalSupply3 = ONE.mul(1230);
      const lastCFMMInvariant3 = ONE.mul(110);
      await testUpdateStore(
        strategy,
        accFeeIndex3,
        lastFeeIndex3,
        lpTokenBalance3,
        borrowedInvariant3,
        lastCFMMTotalSupply3,
        lastCFMMInvariant3
      );
    });

    it.only("Update Index", async function () {
      //TODO: We just have to test that the right fields are increasing as more blocks pass by
      const ONE = BigNumber.from(10).pow(18);
      const cfmmIndex0 = await strategy.getCFMMIndex();
      const storageFields0 = await strategy.getUpdateStoreFields();
      const borrowRate0 = await strategy.borrowRate();
      await (await strategy.setInvariant(ONE.mul(1000))).wait();
      await (await cfmm.mint(ONE.mul(100), owner.address)).wait();
      await (await cfmm.mint(ONE.mul(100), strategy.address)).wait();
      await (
        await strategy.setLPTokenBalAndBorrowedInv(ONE.mul(100), ONE.mul(200))
      ).wait();
      const invariant0 = await strategy.invariant();
      console.log("cfmmIndex0 >>");
      console.log(cfmmIndex0);
      console.log("borrowRate0 >>");
      console.log(borrowRate0);
      console.log("invariant0 >>");
      console.log(invariant0);
      console.log("storageFields0 >>");
      console.log(storageFields0);
      const res = await (await strategy.testUpdateIndex()).wait();
      //console.log("res1 >>");
      //console.log(res.events[0].args);

      const cfmmIndex1 = await strategy.getCFMMIndex();
      const storageFields1 = await strategy.getUpdateStoreFields();
      const borrowRate1 = await strategy.borrowRate();
      const invariant1 = await strategy.invariant();
      console.log("cfmmIndex1 >>");
      console.log(cfmmIndex1);
      console.log("borrowRate1 >>");
      console.log(borrowRate1);
      console.log("invariant1 >>");
      console.log(invariant1);
      console.log("storageFields1 >>");
      console.log(storageFields1);

      await ethers.provider.send("hardhat_mine", ["0x3e8", "0x3c"]);

      const res2 = await (await strategy.testUpdateIndex()).wait();
      //console.log("res2 >>");
      //console.log(res2.events[0].args);

      const cfmmIndex2 = await strategy.getCFMMIndex();
      const storageFields2 = await strategy.getUpdateStoreFields();
      const borrowRate2 = await strategy.borrowRate();
      const invariant2 = await strategy.invariant();
      console.log("cfmmIndex2 >>");
      console.log(cfmmIndex2);
      console.log("borrowRate2 >>");
      console.log(borrowRate2);
      console.log("invariant2 >>");
      console.log(invariant2);
      console.log("storageFields2 >>");
      console.log(storageFields2);
      //event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
      //    uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);
    });
  });

  describe("Update Loan", function () {
    it("Create Loan", async function () {
      const res = await (await strategy.createLoan()).wait();
      expect(res.events[0].args.caller).to.equal(owner.address);
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const accFeeIndex = ONE;
      await checkLoanFields(1, tokenId, accFeeIndex, strategy);

      const accFeeIndex0 = ONE.mul(2);
      await (await strategy.setAccFeeIndex(accFeeIndex0)).wait();
      const res0 = await (await strategy.createLoan()).wait();
      expect(res0.events[0].args.caller).to.equal(owner.address);
      const tokenId0 = res0.events[0].args.tokenId;
      await checkLoanFields(2, tokenId0, accFeeIndex0, strategy);

      const accFeeIndex1 = ONE.mul(3);
      await (await strategy.setAccFeeIndex(accFeeIndex1)).wait();
      const res1 = await (await strategy.createLoan()).wait();
      expect(res1.events[0].args.caller).to.equal(owner.address);
      const tokenId1 = res1.events[0].args.tokenId;
      await checkLoanFields(3, tokenId1, accFeeIndex1, strategy);
    });

    async function checkLoanFields(
      id: number,
      tokenId: BigNumber,
      accFeeIndex: BigNumber,
      strategy: any
    ) {
      const loan = await strategy.getLoan(tokenId);
      expect(loan.id).to.equal(id);
      expect(loan.poolId).to.equal(strategy.address);
      expect(loan.tokensHeld.length).to.equal(2);
      expect(loan.tokensHeld[0]).to.equal(0);
      expect(loan.tokensHeld[1]).to.equal(0);
      expect(loan.liquidity).to.equal(0);
      expect(loan.lpTokens).to.equal(0);
      expect(loan.rateIndex).to.equal(accFeeIndex);
    }

    it("Update Loan Liquidity", async function () {
      // updateLoanLiquidity
      const res = await (await strategy.createLoan()).wait();
      expect(res.events[0].args.caller).to.equal(owner.address);
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const loan = await strategy.getLoan(tokenId);
      expect(loan.id).to.equal(1);
      expect(loan.poolId).to.equal(strategy.address);
      expect(loan.tokensHeld.length).to.equal(2);
      expect(loan.tokensHeld[0]).to.equal(0);
      expect(loan.tokensHeld[1]).to.equal(0);
      expect(loan.liquidity).to.equal(0);
      expect(loan.lpTokens).to.equal(0);
      const accFeeIndex = await strategy.getAccFeeIndex();
      expect(loan.rateIndex).to.equal(accFeeIndex);

      const latestBlock = await ethers.provider.getBlock("latest");
      const blockNumber = BigNumber.from(latestBlock.number);
      expect(loan.blockNum).to.equal(blockNumber);

      const newLiquidity = ONE.mul(1234);
      await (await strategy.setLoanLiquidity(tokenId, newLiquidity)).wait();
      const loan0 = await strategy.getLoan(tokenId);
      expect(loan0.liquidity).to.equal(newLiquidity);

      const newAccFeeIndex = accFeeIndex.mul(ONE.add(ONE.div(10))).div(ONE);
      await testLoanUpdateLiquidity(tokenId, newAccFeeIndex, loan);

      const newAccFeeIndex0 = newAccFeeIndex.mul(ONE.add(ONE.div(20))).div(ONE);
      await testLoanUpdateLiquidity(tokenId, newAccFeeIndex0, loan);

      const newAccFeeIndex1 = newAccFeeIndex0.mul(ONE.add(ONE.div(120))).div(ONE);
      await testLoanUpdateLiquidity(tokenId, newAccFeeIndex1, loan);
    });

    async function testLoanUpdateLiquidity(
      tokenId: BigNumber,
      newAccFeeIndex: BigNumber,
      oldLoan: any
    ) {
      const loan0 = await strategy.getLoan(tokenId);
      expect(loan0.rateIndex).to.lt(newAccFeeIndex);
      expect(loan0.id).to.equal(oldLoan.id);
      expect(loan0.poolId).to.equal(oldLoan.poolId);
      expect(loan0.tokensHeld.length).to.equal(oldLoan.tokensHeld.length);
      expect(loan0.tokensHeld[0]).to.equal(oldLoan.tokensHeld[0]);
      expect(loan0.tokensHeld[1]).to.equal(oldLoan.tokensHeld[1]);
      expect(loan0.lpTokens).to.equal(oldLoan.lpTokens);
      await (
        await strategy.testUpdateLoanLiquidity(tokenId, newAccFeeIndex)
      ).wait();
      const loan = await strategy.getLoan(tokenId);
      expect(loan.liquidity).to.equal(
        updateLoanLiquidity(loan0.liquidity, newAccFeeIndex, loan0.rateIndex)
      );
      expect(loan.liquidity).to.gt(loan0.liquidity);
      expect(loan.rateIndex).to.equal(newAccFeeIndex);
      expect(loan.id).to.equal(oldLoan.id);
      expect(loan.poolId).to.equal(oldLoan.poolId);
      expect(loan.tokensHeld.length).to.equal(oldLoan.tokensHeld.length);
      expect(loan.tokensHeld[0]).to.equal(oldLoan.tokensHeld[0]);
      expect(loan.tokensHeld[1]).to.equal(oldLoan.tokensHeld[1]);
      expect(loan.lpTokens).to.equal(oldLoan.lpTokens);
    }

    function updateLoanLiquidity(
      liquidity: BigNumber,
      accFeeIndex: BigNumber,
      rateIndex: BigNumber
    ): BigNumber {
      return liquidity.mul(accFeeIndex).div(rateIndex);
    }
  });
});
/*
function updateLoanLiquidity(GammaPoolStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual {
        _loan.liquidity = (_loan.liquidity * accFeeIndex) / _loan.rateIndex;
        _loan.rateIndex = accFeeIndex;
    }
* */
