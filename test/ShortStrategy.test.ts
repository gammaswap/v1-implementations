import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

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
    ); /**/
  });

  /* async function deployGammaPool() {
    await (await factory.createPool()).wait();

    const key = await addressCalculator.getGammaPoolKey(
        cfmm.address,
        PROTOCOL_ID
    );
    const pool = await factory.getPool(key);

    gammaPool = await GammaPool.attach(
        pool // The deployed contract address
    );
  }/**/

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
    // await (await gammaPool.mint(shares, owner.address)).wait(); // increase totalSupply of gammaPool

    // expect(await gammaPool.totalSupply()).to.be.equal(_totalSupply.add(shares));
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
  });

  async function execFirstUpdateIndex() {
    const ONE = BigNumber.from(10).pow(18);
    const cfmmInvariant = ONE.mul(1000);
    await (await strategy.setInvariant(cfmmInvariant)).wait();
    await (await cfmm.mint(ONE.mul(100), owner.address)).wait();
    await (await cfmm.mint(ONE.mul(100), strategy.address)).wait();
    const lpTokenBal = ONE.mul(100);
    const borrowedInvariant = ONE.mul(200);
    await (
      await strategy.setLPTokenBalAndBorrowedInv(lpTokenBal, borrowedInvariant)
    ).wait();
    await (await strategy.testUpdateIndex()).wait();
  }

  describe("TotalAssets", function () {
    it("Check TotalAssets before updateIndex", async function () {
      await execFirstUpdateIndex();

      // trades happen
      const cfmmInvariant0 = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant0.mul(2))).wait();

      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await (await strategy.testUpdateIndex()).wait();

      const lpTokenTotal0 = await strategy.getTotalAssets();
      expect(lpTokenTotal0).to.gt(0);

      // trades happen
      const cfmmInvariant1 = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant1.mul(2))).wait();

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

  describe("Conversion Functions", function () {
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

  describe("Preview Functions", function () {
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
