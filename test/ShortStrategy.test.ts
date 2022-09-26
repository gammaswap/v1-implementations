import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { Address } from "cluster";

const PROTOCOL_ID = 1;

describe("ShortStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestStrategyFactory: any;
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
    TestStrategyFactory = await ethers.getContractFactory(
      "TestStrategyFactory"
    );
    TestStrategy = await ethers.getContractFactory("TestShortStrategy");
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
    factory = await TestStrategyFactory.deploy(
      cfmm.address,
      PROTOCOL_ID,
      [tokenA.address, tokenB.address],
      protocol.address
    );

    await (await factory.createShortStrategy()).wait();
    const strategyAddr = await factory.strategy();

    strategy = await TestStrategy.attach(
      strategyAddr // The deployed contract address
    );
  });

  async function convertToShares(
    assets: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    return supply.eq(0) || totalAssets.eq(0)
      ? assets
      : assets.mul(supply).div(totalAssets);
  }

  async function convertToAssets(
    shares: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    return supply.eq(0) ? shares : shares.mul(totalAssets).div(supply);
  }

  // increase totalAssets by assets, increase totalSupply by shares
  async function updateBalances(assets: BigNumber, shares: BigNumber) {
    const _totalAssets = await strategy.getTotalAssets();
    if (assets.gt(0))
      await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool

    expect(await strategy.getTotalAssets()).to.be.equal(
      _totalAssets.add(assets)
    );

    const _totalSupply = await strategy.totalSupply();

    if (shares.gt(0))
      await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool

    expect(await strategy.totalSupply()).to.be.equal(_totalSupply.add(shares));
  }

  async function testConvertToShares(
    assets: BigNumber,
    convert2Shares: Function,
    convert2Assets: Function
  ): Promise<BigNumber> {
    const totalSupply = await strategy.totalSupply();
    const totalAssets = await strategy.getTotalAssets();
    const convertedToShares = await convertToShares(
      assets,
      totalSupply,
      totalAssets
    );

    const _convertedToShares = await convert2Shares(assets);

    expect(_convertedToShares).to.be.equal(convertedToShares);
    expect(await convert2Assets(convertedToShares)).to.be.equal(
      await convertToAssets(convertedToShares, totalSupply, totalAssets)
    );

    return convertedToShares;
  }

  async function testConvertToAssets(
    shares: BigNumber,
    convert2Assets: Function,
    convert2Shares: Function
  ): Promise<BigNumber> {
    const totalSupply = await strategy.totalSupply();
    const totalAssets = await strategy.getTotalAssets();
    const convertedToAssets = await convertToAssets(
      shares,
      totalSupply,
      totalAssets
    );

    const _convertedToAssets = await convert2Assets(shares);

    expect(_convertedToAssets).to.be.equal(convertedToAssets);
    expect(await convert2Shares(convertedToAssets)).to.be.equal(
      await convertToShares(convertedToAssets, totalSupply, totalAssets)
    );

    return convertedToAssets;
  }

  async function execFirstUpdateIndex(
    lpTokens: BigNumber,
    addInvariaint: BigNumber
  ) {
    await (await cfmm.mint(lpTokens, owner.address)).wait();
    await (await cfmm.transfer(strategy.address, lpTokens.div(2))).wait();

    await (await strategy.depositLPTokens(owner.address)).wait();

    await (await cfmm.trade(addInvariaint)).wait();
    await (await strategy.testUpdateIndex()).wait();
  }

  async function borrowLPTokens(lpTokens: BigNumber) {
    await (await strategy.borrowLPTokens(lpTokens)).wait();
    await (await strategy.testUpdateIndex()).wait();
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const assets = ONE.mul(100);
      const _totalAssets = await strategy.getTotalAssets();
      await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool
      expect(await strategy.getTotalAssets()).to.equal(
        _totalAssets.add(assets)
      );

      const shares = ONE.mul(100);
      const _totalSupply = await strategy.totalSupply();
      await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool
      expect(await strategy.totalSupply()).to.equal(_totalSupply.add(shares));
    });

    it("Check Allowance", async function () {
      const allowance = BigNumber.from(100);
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(0);
      await (
        await strategy.setAllowance(owner.address, strategy.address, allowance)
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(100);

      await expect(
        strategy.spendAllowance(
          owner.address,
          strategy.address,
          allowance.add(1)
        )
      ).to.be.revertedWith("amt > allow");

      await (
        await strategy.spendAllowance(
          owner.address,
          strategy.address,
          allowance.div(2)
        )
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(allowance.div(2));

      await (
        await strategy.setAllowance(
          owner.address,
          strategy.address,
          ethers.constants.MaxUint256
        )
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(ethers.constants.MaxUint256);

      await (
        await strategy.spendAllowance(
          owner.address,
          strategy.address,
          ethers.constants.MaxUint256
        )
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(ethers.constants.MaxUint256);
    });

    it("Check First Exec", async function () {
      const ONE = BigNumber.from(10).pow(18);
      await execFirstUpdateIndex(ONE.mul(200), ONE.mul(10));
      const ownerBalance = await cfmm.balanceOf(owner.address);
      const strategyBalance = await cfmm.balanceOf(strategy.address);
      const cfmmTotalSupply = await cfmm.totalSupply();
      expect(ownerBalance).to.equal(cfmmTotalSupply.div(2));
      const cfmmInvariant = await cfmm.invariant();
      const gsTotalSupply = await strategy.totalSupply();
      const ownerGSBalance = await strategy.balanceOf(owner.address);
      expect(gsTotalSupply).to.equal(ownerGSBalance);
      const params = await strategy.getTotalAssetsParams();
      expect(params.lpBalance).to.equal(strategyBalance);
      expect(params.lpBalance).to.equal(cfmmTotalSupply.div(2));

      await borrowLPTokens(ONE.mul(10));
      const params1 = await strategy.getTotalAssetsParams();
      const interest = params1.lpTokenBorrowedPlusInterest.sub(
        params1.lpBorrowed
      );
      expect(params1.lpBorrowed.add(params1.lpBalance)).to.equal(
        params1.lpTokenTotal.sub(interest)
      );
      const cfmmInvariant1 = await cfmm.invariant();
      expect(cfmmInvariant1).to.equal(cfmmInvariant.mul(95).div(100));
    });
  });

  async function checkGSPoolIsEmpty(
    cfmmTotalSupply: BigNumber,
    cfmmTotalInvariant: BigNumber
  ) {
    expect(await strategy.getTotalAssets()).to.equal(0);
    expect(await strategy.totalSupply()).to.equal(0);
    const params = await strategy.getTotalAssetsParams();
    expect(params.borrowedInvariant).to.equal(0);
    expect(params.lpBalance).to.equal(0);
    expect(params.lpBorrowed).to.equal(0);
    expect(params.lpTokenTotal).to.equal(0);
    expect(params.lpTokenBorrowedPlusInterest).to.equal(0);
    expect(params.prevCFMMInvariant).to.equal(cfmmTotalInvariant);
    expect(params.prevCFMMTotalSupply).to.equal(cfmmTotalSupply);
  }

  describe("ERC4626 Write Functions", function () {
    describe("ERC4626 Deposit & Mint", function () {
      it("Error Deposit Assets/LP Tokens", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        await (await cfmm.mint(shares, owner.address)).wait();

        await expect(
          strategy._deposit(ethers.constants.Zero, owner.address)
        ).to.be.revertedWith("ZERO_SHARES");

        const assets = shares.div(2);
        await expect(
          strategy._deposit(assets, owner.address)
        ).to.be.revertedWith("STF_FAIL");
      });

      it("First Deposit Assets/LP Tokens", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        const assets = shares.div(2);
        const expectedGSShares = await strategy.previewDeposit(assets);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await (
          await cfmm.approve(strategy.address, ethers.constants.MaxUint256)
        ).wait();

        const { events } = await (
          await strategy._deposit(assets, owner.address)
        ).wait();

        const depositEvent = events[events.length - 2];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(owner.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(assets);
        expect(depositEvent.args.shares).to.equal(expectedGSShares);

        const poolUpdatedEvent = events[events.length - 1];
        expect(poolUpdatedEvent.event).to.equal("PoolUpdated");
        expect(poolUpdatedEvent.args.lpTokenBalance).to.equal(assets);
        expect(poolUpdatedEvent.args.lpTokenBorrowed).to.equal(0);
        expect(poolUpdatedEvent.args.lastBlockNumber).to.equal(
          (await ethers.provider.getBlock("latest")).number
        );
        expect(poolUpdatedEvent.args.accFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent.args.lastFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent.args.lpTokenBorrowedPlusInterest).to.equal(0);
        expect(poolUpdatedEvent.args.lpInvariant).to.equal(0);
        expect(poolUpdatedEvent.args.borrowedInvariant).to.equal(0);

        expect(await strategy.totalSupply()).to.equal(expectedGSShares);
        expect(await strategy.balanceOf(owner.address)).to.equal(
          expectedGSShares
        );
        const params1 = await strategy.getTotalAssetsParams();
        expect(params1.lpBalance).to.equal(assets);
        expect(assets).to.equal(expectedGSShares);
      });

      it("More Deposit Assets/LP Tokens", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        const assets = shares.div(2);
        const expectedGSShares = await strategy.previewDeposit(assets);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await (
          await cfmm.approve(strategy.address, ethers.constants.MaxUint256)
        ).wait();

        const { events } = await (
          await strategy._deposit(assets, owner.address)
        ).wait();

        const depositEvent = events[events.length - 2];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(owner.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(assets);
        expect(depositEvent.args.shares).to.equal(expectedGSShares);

        expect(await strategy.totalSupply()).to.equal(expectedGSShares);
        expect(await strategy.balanceOf(owner.address)).to.equal(
          expectedGSShares
        );

        await (await cfmm.trade(tradeYield)).wait();

        const assets2 = assets.div(2);
        const expectedGSShares2 = await strategy.previewDeposit(assets2);

        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        const resp = await (
          await strategy._deposit(assets2, owner.address)
        ).wait();

        const depositEvent1 = resp.events[resp.events.length - 2];
        expect(depositEvent1.event).to.equal("Deposit");
        expect(depositEvent1.args.caller).to.equal(owner.address);
        expect(depositEvent1.args.to).to.equal(owner.address);
        expect(depositEvent1.args.assets).to.equal(assets2);
        expect(depositEvent1.args.shares).to.equal(expectedGSShares2);

        await borrowLPTokens(ONE.mul(10));

        await (await cfmm.trade(tradeYield)).wait();
        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        const assets3 = assets2.div(2);
        const params1 = await strategy.getTotalAssetsParams();

        const currTotalAssets = await strategy.totalAssets(
          cfmm.address,
          params1.borrowedInvariant,
          params1.lpBalance,
          params1.lpBorrowed,
          params1.prevCFMMInvariant,
          params1.prevCFMMTotalSupply,
          params1.lastBlockNum.sub(1) // to account for the next block update
        );
        const expectedGSShares3 = assets3
          .mul(await strategy.totalSupply())
          .div(currTotalAssets);

        const resp1 = await (
          await strategy._deposit(assets3, owner.address)
        ).wait();

        const depositEvent2 = resp1.events[resp1.events.length - 2];
        expect(depositEvent2.event).to.equal("Deposit");
        expect(depositEvent2.args.caller).to.equal(owner.address);
        expect(depositEvent2.args.to).to.equal(owner.address);
        expect(depositEvent2.args.assets).to.equal(assets3);
        expect(depositEvent2.args.shares).to.equal(expectedGSShares3);
      });

      it("Mint Shares Error", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const lpTokens = ONE.mul(200);
        await (await cfmm.mint(lpTokens, owner.address)).wait();

        await expect(
          strategy._mint(ethers.constants.Zero, owner.address)
        ).to.be.revertedWith("ZERO_ASSETS");

        const shares = lpTokens.div(2);
        await expect(strategy._mint(shares, owner.address)).to.be.revertedWith(
          "STF_FAIL"
        );
      });

      it("First Mint Shares", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const lpTokens = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(lpTokens, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(lpTokens, lpTokens.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(lpTokens);
        expect(await cfmm.invariant()).to.equal(lpTokens.add(tradeYield));

        const shares = lpTokens.div(2);
        const expectedAssets = await strategy.previewMint(shares);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await (
          await cfmm.approve(strategy.address, ethers.constants.MaxUint256)
        ).wait();

        const { events } = await (
          await strategy._mint(shares, owner.address)
        ).wait();

        const depositEvent = events[events.length - 2];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(owner.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(expectedAssets);
        expect(depositEvent.args.shares).to.equal(shares);

        const poolUpdatedEvent = events[events.length - 1];
        expect(poolUpdatedEvent.event).to.equal("PoolUpdated");
        expect(poolUpdatedEvent.args.lpTokenBalance).to.equal(expectedAssets);
        expect(poolUpdatedEvent.args.lpTokenBorrowed).to.equal(0);
        expect(poolUpdatedEvent.args.lastBlockNumber).to.equal(
          (await ethers.provider.getBlock("latest")).number
        );
        expect(poolUpdatedEvent.args.accFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent.args.lastFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent.args.lpTokenBorrowedPlusInterest).to.equal(0);
        expect(poolUpdatedEvent.args.lpInvariant).to.equal(0);
        expect(poolUpdatedEvent.args.borrowedInvariant).to.equal(0);

        expect(await strategy.totalSupply()).to.equal(shares);
        expect(await strategy.balanceOf(owner.address)).to.equal(shares);
        const params1 = await strategy.getTotalAssetsParams();
        expect(params1.lpBalance).to.equal(expectedAssets);
        expect(expectedAssets).to.equal(shares);
      });

      it("More Mint Shares", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const lpTokens = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(lpTokens, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(lpTokens, lpTokens.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(lpTokens);
        expect(await cfmm.invariant()).to.equal(lpTokens.add(tradeYield));

        const shares = lpTokens.div(2);
        const expectedAssets = await strategy.previewMint(shares);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await (
          await cfmm.approve(strategy.address, ethers.constants.MaxUint256)
        ).wait();

        const { events } = await (
          await strategy._mint(shares, owner.address)
        ).wait();

        const depositEvent = events[events.length - 2];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(owner.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(expectedAssets);
        expect(depositEvent.args.shares).to.equal(shares);

        expect(await strategy.totalSupply()).to.equal(shares);
        expect(await strategy.balanceOf(owner.address)).to.equal(shares);

        await (await cfmm.trade(tradeYield)).wait();

        const shares2 = shares.div(2);
        const params1 = await strategy.getTotalAssetsParams();

        const currTotalAssets = await strategy.totalAssets(
          cfmm.address,
          params1.borrowedInvariant,
          params1.lpBalance,
          params1.lpBorrowed,
          params1.prevCFMMInvariant,
          params1.prevCFMMTotalSupply,
          params1.lastBlockNum.sub(1) // to account for the next block update
        );
        const expectedAssets2 = shares2
          .mul(currTotalAssets)
          .div(await strategy.totalSupply());

        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        const resp = await (
          await strategy._mint(shares2, owner.address)
        ).wait();

        const depositEvent1 = resp.events[resp.events.length - 2];
        expect(depositEvent1.event).to.equal("Deposit");
        expect(depositEvent1.args.caller).to.equal(owner.address);
        expect(depositEvent1.args.to).to.equal(owner.address);
        expect(depositEvent1.args.assets).to.equal(expectedAssets2);
        expect(depositEvent1.args.shares).to.equal(shares2);

        await borrowLPTokens(ONE.mul(10));

        await (await cfmm.trade(tradeYield)).wait();
        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        const shares3 = shares2.div(2);
        const params2 = await strategy.getTotalAssetsParams();

        const currTotalAssets2 = await strategy.totalAssets(
          cfmm.address,
          params2.borrowedInvariant,
          params2.lpBalance,
          params2.lpBorrowed,
          params2.prevCFMMInvariant,
          params2.prevCFMMTotalSupply,
          params2.lastBlockNum.sub(1) // to account for the next block update
        );
        const expectedAssets3 = shares3
          .mul(currTotalAssets2)
          .div(await strategy.totalSupply());

        const resp1 = await (
          await strategy._mint(shares3, owner.address)
        ).wait();

        const depositEvent2 = resp1.events[resp1.events.length - 2];
        expect(depositEvent2.event).to.equal("Deposit");
        expect(depositEvent2.args.caller).to.equal(owner.address);
        expect(depositEvent2.args.to).to.equal(owner.address);
        expect(depositEvent2.args.assets).to.equal(expectedAssets3);
        expect(depositEvent2.args.shares).to.equal(shares3);
      });
    });
    describe("ERC4626 Withdraw & Redeem", function () {
      it("Withdraw Assets Transfer Error", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const receiverAddr = owner.address;
        const ownerAddr = addr1.address;
        const callerAddr = owner.address;
        const assets = ONE.mul(25);
        const shares = ONE.mul(50);
        await expect(
          strategy.withdrawAssets(
            callerAddr,
            receiverAddr,
            ownerAddr,
            assets,
            shares
          )
        ).to.be.revertedWith("amt > allow");
      });

      it("Withdraw Assets", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        const withdrawAssets = ONE.mul(25);
        const shares = ONE.mul(50);

        await testWithdrawal(
          owner.address,
          owner.address,
          addr1.address,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          withdrawAssets,
          shares,
          ethers.constants.Zero
        );

        await testWithdrawal(
          owner.address,
          owner.address,
          owner.address,
          withdrawAssets,
          shares,
          withdrawAssets,
          withdrawAssets,
          shares,
          shares
        );

        await prepareAssetsToWithdraw(assets, addr1);

        await (
          await strategy.setAllowance(
            addr1.address,
            owner.address,
            ethers.constants.MaxUint256
          )
        ).wait();

        await testWithdrawal(
          owner.address,
          addr1.address,
          owner.address,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          withdrawAssets,
          shares,
          ethers.constants.Zero
        );

        await testWithdrawal(
          owner.address,
          addr1.address,
          addr1.address,
          withdrawAssets,
          shares,
          withdrawAssets,
          withdrawAssets,
          shares,
          shares
        );
      });

      it("ERC4626 Withdraw Error", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        await expect(
          strategy._withdraw(assets.add(1), addr1.address, owner.address)
        ).to.be.revertedWith("withdraw > max");

        await expect(
          strategy._withdraw(
            ethers.constants.Zero,
            addr1.address,
            owner.address
          )
        ).to.be.revertedWith("ZERO_SHARES");
      });

      it("ERC4626 Withdraw", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        const withdrawAssets = ONE.mul(50);
        const shares = ONE.mul(50);

        await testERC4626Withdraw(
          owner.address,
          addr1.address,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          erc4626Withdraw
        );

        await testERC4626Withdraw(
          owner.address,
          owner.address,
          withdrawAssets,
          shares,
          withdrawAssets,
          withdrawAssets,
          shares,
          shares,
          erc4626Withdraw
        );
      });

      it("ERC4626 Redeem Error", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        await expect(
          strategy._redeem(assets.add(1), addr1.address, owner.address)
        ).to.be.revertedWith("redeem > max");

        await expect(
          strategy._redeem(ethers.constants.Zero, addr1.address, owner.address)
        ).to.be.revertedWith("ZERO_ASSETS");
      });

      it("ERC4626 Redeem", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        const withdrawAssets = ONE.mul(50);
        const shares = ONE.mul(50);

        await testERC4626Withdraw(
          owner.address,
          addr1.address,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          erc4626Redeem
        );

        await testERC4626Withdraw(
          owner.address,
          owner.address,
          withdrawAssets,
          shares,
          withdrawAssets,
          withdrawAssets,
          shares,
          shares,
          erc4626Redeem
        );
      });

      async function checkWithdrawal(
        ownerAddr: Address,
        receiverAddr: Address,
        expTotalSupply: BigNumber,
        expOwnerBalance: BigNumber,
        expReceiverBalance: BigNumber,
        expTotalCFMMSupply: BigNumber,
        expStrategyCFMMSupply: BigNumber,
        expOwnerCFMMBalance: BigNumber,
        expReceiverCFMMBalance: BigNumber
      ) {
        const totalSupply = await strategy.totalSupply();
        expect(totalSupply).to.equal(expTotalSupply);

        const ownerBalance = await strategy.balanceOf(ownerAddr);
        expect(ownerBalance).to.equal(expOwnerBalance);

        const receiverBalance = await strategy.balanceOf(receiverAddr);
        expect(receiverBalance).to.equal(expReceiverBalance);

        const totalCFMMSupply = await cfmm.totalSupply();
        expect(totalCFMMSupply).to.equal(expTotalCFMMSupply);

        const strategyCFMMBalance = await cfmm.balanceOf(strategy.address);
        expect(strategyCFMMBalance).to.equal(expStrategyCFMMSupply);

        const ownerCFMMBalance = await cfmm.balanceOf(ownerAddr);
        expect(ownerCFMMBalance).to.equal(expOwnerCFMMBalance);

        const receiverCFMMBalance = await cfmm.balanceOf(receiverAddr);
        expect(receiverCFMMBalance).to.equal(expReceiverCFMMBalance);

        const resp = await strategy.getLPTokenBalAndBorrowedInv();
        expect(resp.lpTokenBal).to.equal(strategyCFMMBalance);
      }

      async function prepareAssetsToWithdraw(assets: BigNumber, to: any) {
        await (await cfmm.mint(assets, to.address)).wait();
        await (
          await cfmm.connect(to).transfer(strategy.address, assets)
        ).wait();
        await (await strategy.depositLPTokens(to.address)).wait();
      }

      async function testWithdrawal(
        caller: Address,
        from: Address,
        to: Address,
        assets: BigNumber,
        shares: BigNumber,
        ownerAssetChange: BigNumber,
        receiverAssetChange: BigNumber,
        ownerShareChange: BigNumber,
        receiverShareChange: BigNumber
      ) {
        const resp = await strategy.getLPTokenBalAndBorrowedInv();

        const totalSupply = await strategy.totalSupply();
        const ownerBalance = await strategy.balanceOf(from);
        const receiverBalance = await strategy.balanceOf(to);
        const totalCFMMSupply = await cfmm.totalSupply();
        const strategyCFMMBalance = await cfmm.balanceOf(strategy.address);
        const ownerCFMMBalance = await cfmm.balanceOf(from);
        const receiverCFMMBalance = await cfmm.balanceOf(to);

        expect(resp.lpTokenBal).to.equal(strategyCFMMBalance);

        const receiverAddr = to;
        const ownerAddr = from;
        const callerAddr = caller;

        await (
          await strategy.withdrawAssets(
            callerAddr,
            receiverAddr,
            ownerAddr,
            assets,
            shares
          )
        ).wait();

        await checkWithdrawal(
          from,
          to,
          totalSupply.sub(shares),
          ownerBalance.sub(ownerShareChange),
          receiverBalance.sub(receiverShareChange),
          totalCFMMSupply,
          strategyCFMMBalance.sub(assets),
          ownerCFMMBalance.add(ownerAssetChange),
          receiverCFMMBalance.add(receiverAssetChange)
        );
      }

      async function erc4626Withdraw(
        assets: BigNumber,
        to: Address,
        from: Address
      ) {
        await (await strategy._withdraw(assets, to, from)).wait();
      }

      async function erc4626Redeem(
        shares: BigNumber,
        to: Address,
        from: Address
      ) {
        await (await strategy._redeem(shares, to, from)).wait();
      }

      async function testERC4626Withdraw(
        from: Address,
        to: Address,
        assets: BigNumber,
        shares: BigNumber,
        ownerAssetChange: BigNumber,
        receiverAssetChange: BigNumber,
        ownerShareChange: BigNumber,
        receiverShareChange: BigNumber,
        erc4626WithdrawFunc: Function
      ) {
        const resp = await strategy.getLPTokenBalAndBorrowedInv();

        const totalSupply = await strategy.totalSupply();
        const ownerBalance = await strategy.balanceOf(from);
        const receiverBalance = await strategy.balanceOf(to);
        const totalCFMMSupply = await cfmm.totalSupply();
        const strategyCFMMBalance = await cfmm.balanceOf(strategy.address);
        const ownerCFMMBalance = await cfmm.balanceOf(from);
        const receiverCFMMBalance = await cfmm.balanceOf(to);

        expect(resp.lpTokenBal).to.equal(strategyCFMMBalance);

        const receiverAddr = to;
        const ownerAddr = from;

        await erc4626WithdrawFunc(assets, receiverAddr, ownerAddr);

        await checkWithdrawal(
          from,
          to,
          totalSupply.sub(shares),
          ownerBalance.sub(ownerShareChange),
          receiverBalance.sub(receiverShareChange),
          totalCFMMSupply,
          strategyCFMMBalance.sub(assets),
          ownerCFMMBalance.add(ownerAssetChange),
          receiverCFMMBalance.add(receiverAssetChange)
        );
      }
    });
  });

  describe("ERC4626 TotalAssets", function () {
    it("No Assets", async function () {
      const totAssets = await strategy.getTotalAssets();
      expect(totAssets).to.equal(0);

      const params = await strategy.getTotalAssetsParams();
      const currTotalAssets = await strategy.totalAssets(
        cfmm.address,
        params.borrowedInvariant,
        params.lpBalance,
        params.lpBorrowed,
        params.prevCFMMInvariant,
        params.prevCFMMTotalSupply,
        params.lastBlockNum.sub(1) // to account for the next block update
      );
      expect(currTotalAssets).to.equal(0);

      await (await strategy.testUpdateIndex()).wait();
      const totAssets1 = await strategy.getTotalAssets();
      expect(totAssets1).to.equal(0);

      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      const params1 = await strategy.getTotalAssetsParams();
      const currTotalAssets1 = await strategy.totalAssets(
        cfmm.address,
        params1.borrowedInvariant,
        params1.lpBalance,
        params1.lpBorrowed,
        params1.prevCFMMInvariant,
        params1.prevCFMMTotalSupply,
        params1.lastBlockNum.sub(1) // to account for the next block update
      );
      expect(currTotalAssets1).to.equal(0);

      await (await strategy.testUpdateIndex()).wait();
      const totAssets2 = await strategy.getTotalAssets();
      expect(totAssets2).to.equal(0);
    });

    it("Check TotalAssets before updateIndex", async function () {
      const ONE = BigNumber.from(10).pow(18);
      await execFirstUpdateIndex(ONE.mul(200), ONE.mul(10));

      await borrowLPTokens(ONE.mul(10));
      // trades happen
      await (await cfmm.trade(ONE.mul(50))).wait();
      // const cfmmInvariant0 = await strategy.invariant();
      // await (await strategy.setInvariant(cfmmInvariant0.mul(2))).wait();

      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await (await strategy.testUpdateIndex()).wait();

      const lpTokenTotal0 = await strategy.getTotalAssets();
      expect(lpTokenTotal0).to.gt(0);

      // trades happen
      await (await cfmm.trade(ONE.mul(50))).wait();
      // const cfmmInvariant1 = await strategy.invariant();
      // await (await strategy.setInvariant(cfmmInvariant1.mul(2))).wait();

      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      const lpTokenTotal1 = await strategy.getTotalAssets();
      expect(lpTokenTotal1).to.equal(lpTokenTotal0);

      const params = await strategy.getTotalAssetsParams();

      const currTotalAssets = await strategy.totalAssets(
        cfmm.address,
        params.borrowedInvariant,
        params.lpBalance,
        params.lpBorrowed,
        params.prevCFMMInvariant,
        params.prevCFMMTotalSupply,
        params.lastBlockNum.sub(1) // to account for the next block update
      );

      await (await strategy.testUpdateIndex()).wait();

      expect(await strategy.getTotalAssets()).to.equal(currTotalAssets);
    });
  });

  describe("ERC4626 Conversion Functions", function () {
    it("Check convertToShares & convertToAssets, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(0);

      expect(
        await testConvertToShares(
          assets0,
          strategy.convertToShares,
          strategy.convertToAssets
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy.convertToAssets,
          strategy.convertToShares
        )
      ).to.be.equal(shares0);

      // supply == 0, (assets > 0, shares == 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(0);

      await updateBalances(assets1, shares1);

      expect(
        await testConvertToShares(
          assets1,
          strategy.convertToShares,
          strategy.convertToAssets
        )
      ).to.be.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy.convertToAssets,
          strategy.convertToShares
        )
      ).to.be.equal(shares1);
    });

    it("Check convertToShares & convertToAssets, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(100);

      await updateBalances(assets0, shares0);

      expect(
        await testConvertToShares(
          assets0,
          strategy.convertToShares,
          strategy.convertToAssets
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy.convertToAssets,
          strategy.convertToShares
        )
      ).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(100);

      await updateBalances(assets1, shares1); // increase totalAssets by 1000, increase totalSupply by 100

      expect(
        await testConvertToShares(
          assets1,
          strategy.convertToShares,
          strategy.convertToAssets
        )
      ).to.not.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy.convertToAssets,
          strategy.convertToShares
        )
      ).to.not.equal(shares1);

      // supply > 0, (assets > 0, shares > 0)
      const assets2 = ONE.mul(3000);
      const shares2 = ONE.mul(200);

      await updateBalances(assets2, shares2); // increase totalAssets by 3000, increase totalSupply by 200

      expect(
        await testConvertToShares(
          assets2,
          strategy.convertToShares,
          strategy.convertToAssets
        )
      ).to.not.equal(assets2);
      expect(
        await testConvertToAssets(
          shares2,
          strategy.convertToAssets,
          strategy.convertToShares
        )
      ).to.not.equal(shares2);
    });
  });

  describe("ERC4626 Preview Functions", function () {
    it("Check previewDeposit & previewMint, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(0);

      expect(
        await testConvertToShares(
          assets0,
          strategy.previewDeposit,
          strategy.previewMint
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy.previewMint,
          strategy.previewDeposit
        )
      ).to.be.equal(shares0);

      // supply == 0, (assets > 0, shares == 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(0);

      await updateBalances(assets1, shares1);

      expect(
        await testConvertToShares(
          assets1,
          strategy.previewMint,
          strategy.convertToAssets
        )
      ).to.be.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy.convertToAssets,
          strategy.previewMint
        )
      ).to.be.equal(shares1);
    });

    it("Check previewDeposit & previewMint, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(100);

      await updateBalances(assets0, shares0);

      expect(
        await testConvertToShares(
          assets0,
          strategy.previewDeposit,
          strategy.previewMint
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy.previewMint,
          strategy.previewDeposit
        )
      ).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(100);

      await updateBalances(assets1, shares1); // increase totalAssets by 1000, increase totalSupply by 100

      expect(
        await testConvertToShares(
          assets1,
          strategy.previewDeposit,
          strategy.previewMint
        )
      ).to.not.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy.previewMint,
          strategy.previewDeposit
        )
      ).to.not.equal(shares1);

      // supply > 0, (assets > 0, shares > 0)
      const assets2 = ONE.mul(4000);
      const shares2 = ONE.mul(500);

      await updateBalances(assets2, shares2); // increase totalAssets by 4000, increase totalSupply by 500

      expect(
        await testConvertToShares(
          assets2,
          strategy.previewDeposit,
          strategy.previewMint
        )
      ).to.not.equal(assets2);
      expect(
        await testConvertToAssets(
          shares2,
          strategy.previewMint,
          strategy.previewDeposit
        )
      ).to.not.equal(shares2);
    });

    it("Check previewWithdraw and previewRedeem, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(0);

      expect(
        await testConvertToShares(
          assets0,
          strategy.previewWithdraw,
          strategy.previewRedeem
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy.previewRedeem,
          strategy.previewWithdraw
        )
      ).to.be.equal(shares0);

      // supply == 0, (assets > 0, shares == 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(0);

      await updateBalances(assets1, shares1);

      expect(
        await testConvertToShares(
          assets1,
          strategy.previewWithdraw,
          strategy.previewRedeem
        )
      ).to.be.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy.previewRedeem,
          strategy.previewWithdraw
        )
      ).to.be.equal(shares1);
    });

    it("Check previewWithdraw and previewRedeem, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(100);

      await updateBalances(assets0, shares0);

      expect(
        await testConvertToShares(
          assets0,
          strategy.previewWithdraw,
          strategy.previewRedeem
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy.previewRedeem,
          strategy.previewWithdraw
        )
      ).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(10000);

      await updateBalances(assets1, shares1); // increase totalAssets by 1000, increase totalSupply by 10000

      expect(
        await testConvertToShares(
          assets1,
          strategy.previewWithdraw,
          strategy.previewRedeem
        )
      ).to.not.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy.previewRedeem,
          strategy.previewWithdraw
        )
      ).to.not.equal(shares1);

      // supply > 0, (assets > 0, shares > 0)
      const assets2 = ONE.mul(300);
      const shares2 = ONE.mul(2000);

      await updateBalances(assets2, shares2); // increase totalAssets by 1000, increase totalSupply by 2000

      expect(
        await testConvertToShares(
          assets2,
          strategy.previewWithdraw,
          strategy.previewRedeem
        )
      ).to.not.equal(assets2);
      expect(
        await testConvertToAssets(
          shares2,
          strategy.previewRedeem,
          strategy.previewWithdraw
        )
      ).to.not.equal(shares2);
    });
  });
});
