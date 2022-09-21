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

  describe("Update CFMM Index", function () {
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
  });

  /*
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
  * */
  describe("Update Fee Index", function () {
    it.only("Update Fee Index", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      await (await strategy.setCFMMIndex(ONE)).wait();
      const cfmmFeeIndex = await strategy.getCFMMIndex();
      const lastBlockNumber = await strategy.getLastBlockNumber();
      console.log("cfmmFeeIndex >>");
      console.log(cfmmFeeIndex);
      console.log("lastBlockNumber >>");
      console.log(lastBlockNumber);
      const latestBlock = await ethers.provider.getBlock("latest");
      console.log("latestBlock >>");
      console.log(latestBlock.number);

      await (await strategy.testUpdateFeeIndex()).wait();

      const lastFeeIndex = await strategy.getLastFeeIndex();
      console.log("lastFeeIndex >>");
      console.log(lastFeeIndex);
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      // mine 1000 blocks with an interval of 1 minute
      await ethers.provider.send("hardhat_mine", ["0x3e8", "0x3c"]);

      const latestBlock0 = await ethers.provider.getBlock("latest");
      console.log("latestBlock0 >>");
      console.log(latestBlock0.number);
    });
  });
});
