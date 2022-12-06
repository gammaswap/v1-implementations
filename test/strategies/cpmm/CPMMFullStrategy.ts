import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");
const GammaPoolFactoryJSON = require("@gammaswap/v1-core/artifacts/contracts/GammaPoolFactory.sol/GammaPoolFactory.json");
const CPMMGammaPoolJSON = require("@gammaswap/v1-core/artifacts/contracts/pools/CPMMGammaPool.sol/CPMMGammaPool.json");

const PROTOCOL_ID = 1;

describe("CPMM Full Strategy", function () {
  let TestERC20: any;
  let UniswapV2Factory: any;
  let UniswapV2Pair: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let uniFactory: any;
  let owner: any;

  let PositionManager: any;
  let GammaPoolFactory: any;
  let GammaPool: any;
  let factory: any;
  let protocol: any;
  let gammaPool: any;
  let CPMMLongStrategy: any;
  let CPMMShortStrategy: any;
  let CPMMLiquidationStrategy: any;
  let longStrategy: any;
  let shortStrategy: any;
  let liquidationStrategy: any;
  let WETH: any;
  let posMgr: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");

    [owner] = await ethers.getSigners();

    GammaPool = new ethers.ContractFactory(
      CPMMGammaPoolJSON.abi,
      CPMMGammaPoolJSON.bytecode,
      owner
    );

    GammaPoolFactory = new ethers.ContractFactory(
      GammaPoolFactoryJSON.abi,
      GammaPoolFactoryJSON.bytecode,
      owner
    );

    PositionManager = await ethers.getContractFactory("TestPositionManager2");

    UniswapV2Factory = new ethers.ContractFactory(
      UniswapV2FactoryJSON.abi,
      UniswapV2FactoryJSON.bytecode,
      owner
    );

    uniFactory = await UniswapV2Factory.deploy(owner.address);

    factory = await GammaPoolFactory.deploy(owner.address);

    CPMMLongStrategy = await ethers.getContractFactory("CPMMLongStrategy");
    CPMMShortStrategy = await ethers.getContractFactory("CPMMShortStrategy");
    CPMMLiquidationStrategy = await ethers.getContractFactory(
      "CPMMLiquidationStrategy"
    );

    WETH = await TestERC20.deploy("Wrapped Ethereum", "WETH");

    posMgr = await PositionManager.deploy(factory.address, WETH.address);

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    longStrategy = await CPMMLongStrategy.deploy(
      0,
      997,
      1000,
      baseRate,
      factor,
      maxApy
    );

    shortStrategy = await CPMMShortStrategy.deploy(baseRate, factor, maxApy);

    liquidationStrategy = await CPMMLiquidationStrategy.deploy(
      997,
      1000,
      baseRate,
      factor,
      maxApy
    );
    // 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    const cfmmHash =
      "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f";
    protocol = await GammaPool.deploy(
      PROTOCOL_ID,
      factory.address,
      longStrategy.address, // long strategy
      shortStrategy.address, // short strategy
      liquidationStrategy.address, // liquidation strategy
      uniFactory.address,
      cfmmHash
    );

    await (await factory.addProtocol(protocol.address)).wait();

    UniswapV2Pair = new ethers.ContractFactory(
      UniswapV2PairJSON.abi,
      UniswapV2PairJSON.bytecode,
      owner
    );

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    cfmm = await createPair(tokenA, tokenB);

    // because Uniswap's CFMM reorders tokenA and tokenB in increasing order
    const token0addr = await cfmm.token0();
    const token1addr = await cfmm.token1();

    tokenA = await TestERC20.attach(
      token0addr // The deployed contract address
    );
    tokenB = await TestERC20.attach(
      token1addr // The deployed contract address
    );

    await tokenA.transfer(cfmm.address, ONE.mul(100));
    await tokenB.transfer(cfmm.address, ONE.mul(100));

    const tx = await (await cfmm.mint(owner.address)).wait();

    const createPoolParams = {
      protocolId: PROTOCOL_ID,
      cfmm: cfmm.address,
      tokens: [tokenA.address, tokenB.address],
    };
    const tx1 = await (
      await factory.createPool(
        createPoolParams.protocolId,
        createPoolParams.cfmm,
        createPoolParams.tokens
      )
    ).wait();

    const gammaPoolAddr = tx1.events[0].args.pool;
    gammaPool = await GammaPool.attach(
      gammaPoolAddr // The deployed contract address
    );
  });

  async function createPair(token1: any, token2: any) {
    await uniFactory.createPair(token1.address, token2.address);
    const uniPairAddress: string = await uniFactory.getPair(
      token1.address,
      token2.address
    );

    return await UniswapV2Pair.attach(
      uniPairAddress // The deployed contract address
    );
  }

  describe("CPMM Full Strategy Test", function () {
    it("Deposit, Borrow, & Rebalance", async function () {
      const reserves = await cfmm.getReserves();
      const bal = await cfmm.balanceOf(owner.address);

      const ONE = BigNumber.from(10).pow(18);

      const DepositWithdrawParams = {
        protocolId: PROTOCOL_ID,
        cfmm: cfmm.address,
        to: owner.address,
        lpTokens: ONE.mul(10),
        deadline: ethers.constants.MaxUint256,
      };

      const res0 = await (
        await cfmm.approve(posMgr.address, ethers.constants.MaxUint256)
      ).wait();

      const res1 = await (
        await posMgr.depositNoPull(DepositWithdrawParams)
      ).wait();

      const res2 = await (
        await posMgr.createLoan(
          1,
          cfmm.address,
          owner.address,
          ethers.constants.MaxUint256
        )
      ).wait();

      const event = res2.events[1];
      const tokenId = event.args.tokenId;

      await (
        await tokenA.approve(posMgr.address, ethers.constants.MaxUint256)
      ).wait();
      await (
        await tokenB.approve(posMgr.address, ethers.constants.MaxUint256)
      ).wait();

      const AddRemoveCollateralParams = {
        cfmm: cfmm.address,
        protocolId: PROTOCOL_ID,
        tokenId: tokenId,
        amounts: [ONE.mul(10), ONE.mul(10)],
        to: owner.address,
        deadline: ethers.constants.MaxUint256,
      };

      const res3 = await (
        await posMgr.increaseCollateral(AddRemoveCollateralParams)
      ).wait();

      const BorrowLiquidityParams = {
        cfmm: cfmm.address,
        protocolId: PROTOCOL_ID,
        tokenId: tokenId,
        lpTokens: ONE.mul(2),
        to: owner.address,
        minBorrowed: [0, 0],
        deadline: ethers.constants.MaxUint256,
      };

      const res4 = await (
        await posMgr.borrowLiquidity(BorrowLiquidityParams)
      ).wait();

      const res5 = await gammaPool.loan(tokenId);

      const RebalanceCollateralParams = {
        cfmm: cfmm.address,
        protocolId: PROTOCOL_ID,
        tokenId: tokenId,
        deltas: [ONE.mul(10), 0],
        liquidity: 1,
        to: owner.address,
        minCollateral: [0, 0],
        deadline: ethers.constants.MaxUint256,
      };

      const res6 = await (
        await posMgr.rebalanceCollateral(RebalanceCollateralParams)
      ).wait();

      const res7 = await gammaPool.loan(tokenId);
    });
  });
});
