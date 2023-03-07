import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");
const _WeightedPoolAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPool.json");
const _WeightedPoolBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPool.json");

describe("BalancerLongStrategy", function () {
  let TestERC20: any;
  let TestERC20Decimals: any;

  let TestStrategy: any;

  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let WeightedPool: any;

  let tokenA: any;
  let tokenB: any;
  let tokenC: any;

  let cfmm: any;
  let cfmmDecimals: any;

  let vault: any;
  let factory: any;
  let strategy: any;
  let strategyDecimals: any;

  let owner: any;
  let pool: any;
  let decimalsPool: any;
  let cfmmPoolId: any;
  let cfmmDecimalsPoolId: any;

  let WEIGHTS: any;
  let cfmmTokens: any;
  let cfmmDecimalsTokens: any;
  let cfmmTokenDecimals: any;
  let cfmmDecimalsTokenDecimals: any;

  beforeEach(async function () {
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestERC20Decimals = await ethers.getContractFactory("TestERC20Decimals");
    [owner] = await ethers.getSigners();

    // Get contract factory for WeightedPool: '@balancer-labs/v2-pool-weighted/WeightedPoolFactory'
    WeightedPoolFactory = new ethers.ContractFactory(
      _WeightedPoolFactoryAbi,
      _WeightedPoolFactoryBytecode.creationCode,
      owner
    );

    WeightedPool = new ethers.ContractFactory(
      _WeightedPoolAbi,
      _WeightedPoolBytecode.creationCode,
      owner
    );

    // Get contract factory for Vault: '@balancer-labs/v2-vault/contracts/Vault'
    BalancerVault = new ethers.ContractFactory(
      _Vault.abi,
      _Vault.bytecode,
      owner
    );

    TestStrategy = await ethers.getContractFactory("TestBalancerLongStrategy");

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20Decimals.deploy("Test Token C", "TOKC");

    const HOUR = 60 * 60;
    const DAY = HOUR * 24;
    const MONTH = DAY * 30;

    // Deploy the Vault contract
    vault = await BalancerVault.deploy(
      owner.address,
      tokenA.address,
      MONTH,
      MONTH
    );

    // Deploy the WeightedPoolFactory contract
    factory = await WeightedPoolFactory.deploy(vault.address);

    // Create a WeightedPool using the WeightedPoolFactory
    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    // Initialise a strategy with [18, 18] decimals
    // Create a WeightedPool using the WeightedPoolFactory
    const feePercentage = BigNumber.from(10).pow(18).div(100);
    const res = await createPair([tokenA, tokenB], feePercentage);
    cfmm = res[0];
    cfmmTokens = res[1];

    pool = WeightedPool.attach(cfmm);
    cfmmPoolId = await pool.getPoolId();
    cfmmTokenDecimals = await sortDecimals(tokenA, tokenB);

    const HUNDRETH = BigNumber.from(10).pow(16);

    strategy = await TestStrategy.deploy(
      0,
      baseRate,
      factor,
      maxApy,
      BigNumber.from(20).mul(HUNDRETH)
    );

    const _data = ethers.utils.defaultAbiCoder.encode(
      ["bytes32"], // encode as address array
      [cfmmPoolId]
    );

    await (
      await strategy.initialize(
        cfmm,
        sortTokens(tokenA, tokenB),
        await sortDecimals(tokenA, tokenB),
        _data,
        vault.address
      )
    ).wait();

    // Initialise a strategy with [18, 6] decimals
    const res1 = await createPair([tokenA, tokenC], feePercentage);
    cfmmDecimals = res1[0];
    cfmmDecimalsTokens = res1[1];

    decimalsPool = WeightedPool.attach(cfmmDecimals);
    cfmmDecimalsPoolId = await decimalsPool.getPoolId();
    cfmmDecimalsTokenDecimals = await sortDecimals(tokenA, tokenC);

    strategyDecimals = await TestStrategy.deploy(
      0,
      baseRate,
      factor,
      maxApy,
      BigNumber.from(20).mul(HUNDRETH)
    );

    const _data0 = ethers.utils.defaultAbiCoder.encode(
      ["bytes32"], // encode as address array
      [cfmmDecimalsPoolId]
    );

    await (
      await strategyDecimals.initialize(
        cfmmDecimals,
        sortTokens(tokenA, tokenC),
        await sortDecimals(tokenA, tokenC),
        _data0,
        vault.address
      )
    ).wait();
  });

  function sortTokens(token1: any, token2: any) {
    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      return [token2.address, token1.address];
    } else {
      return [token1.address, token2.address];
    }
  }

  async function sortDecimals(token1: any, token2: any) {
    if (BigNumber.from(token1.address).lt(BigNumber.from(token2.address))) {
      return [await token1.decimals(), await token2.decimals()];
    } else {
      return [await token2.decimals(), await token1.decimals()];
    }
  }

  async function createPair(tokens: any, fee_percent: any) {
    const NAME = "TESTPOOL";
    const SYMBOL = "TP";

    const _TOKENS = sortTokens(tokens[0], tokens[1]);

    const HUNDRETH = BigNumber.from(10).pow(16);

    WEIGHTS = [
      BigNumber.from(20).mul(HUNDRETH),
      BigNumber.from(80).mul(HUNDRETH),
    ];

    const poolReturnData = await factory.create(
      NAME,
      SYMBOL,
      _TOKENS,
      WEIGHTS,
      fee_percent,
      owner.address
    );

    const receipt = await poolReturnData.wait();

    const events = receipt.events.filter((e: any) => e.event === "PoolCreated");

    const poolAddress = events[0].args.pool;

    return [poolAddress, _TOKENS];
  }

  function expectEqualWithError(actual: BigNumber, expected: BigNumber) {
    const error = actual.sub(expected).abs();
    expect(error.mul(100000).div(expected).lte(1000)).to.be.equal(true);
  }

  async function initialisePool(
    initialBalances: any,
    poolId: any,
    tokens: any
  ) {
    // We must perform an INIT join at the beginning to start the pool
    const JOIN_KIND_INIT = 0;
    const initUserData = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "uint256[]"],
      [JOIN_KIND_INIT, initialBalances]
    );

    // We must approve the vault to spend the tokens we own
    await tokens[0].approve(vault.address, ethers.constants.MaxUint256);
    await tokens[1].approve(vault.address, ethers.constants.MaxUint256);

    const orderedTokens = sortTokens(tokens[0], tokens[1]);

    const joinPoolRequest = {
      assets: orderedTokens,
      maxAmountsIn: initialBalances,
      userData: initUserData,
      fromInternalBalance: false,
    };

    await (
      await vault.joinPool(
        poolId,
        owner.address,
        owner.address,
        joinPoolRequest
      )
    ).wait();
  }

  async function setUpStrategyAndBalancerPool(tokenId: any) {
    const ONE = BigNumber.from(10).pow(18);

    const collateral0 = ONE.mul(100);
    const collateral1 = ONE.mul(200);
    const balance0 = ONE.mul(100);
    const balance1 = ONE.mul(200);

    // Send the strategy the balance of tokens
    if (cfmmTokens[0] == tokenA.address) {
      await (await tokenA.transfer(strategy.address, balance0)).wait();
      await (await tokenB.transfer(strategy.address, balance1)).wait();
    } else {
      await (await tokenA.transfer(strategy.address, balance1)).wait();
      await (await tokenB.transfer(strategy.address, balance0)).wait();
    }

    // Set the strategy's TOKEN_BALANCE array and update tokensHeld in the loan
    await (
      await strategy.setTokenBalances(
        tokenId,
        collateral0,
        collateral1,
        balance0,
        balance1
      )
    ).wait();

    // Initialise the Balancer pool with 5000 tokenA and 10000 tokenB
    await initialisePool([ONE.mul(500), ONE.mul(1000)], cfmmPoolId, [
      tokenA,
      tokenB,
    ]);
    const reserves = await strategy.testGetPoolReserves(cfmm);

    const reserves0 = reserves[0];
    const reserves1 = reserves[1];
    await (await strategy.setCFMMReserves(reserves0, reserves1, 0)).wait();

    return { reserves0: reserves0, reserves1: reserves1 };
  }

  describe("Deployment", function () {
    it("Check Initialisation Parameters for CFMM", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const baseRate = ONE.div(100);
      const factor = ONE.mul(4).div(100);
      const maxApy = ONE.mul(75).div(100);

      // Check strategy params are correct
      expect(await strategy.baseRate()).to.equal(baseRate);
      expect(await strategy.factor()).to.equal(factor);
      expect(await strategy.maxApy()).to.equal(maxApy);

      // Check the strategy parameters align
      const HUNDRETH = BigNumber.from(10).pow(16);
      const WEIGHTS = [
        BigNumber.from(20).mul(HUNDRETH),
        BigNumber.from(80).mul(HUNDRETH),
      ];

      expect(pool.address).to.equal(cfmm);
      expect(await strategy.getCFMM()).to.equal(cfmm);
      expect(await strategy.getCFMMReserves()).to.deep.equal([
        BigNumber.from(0),
        BigNumber.from(0),
      ]);
      expect(await strategy.testGetVault(cfmm)).to.equal(await pool.getVault());
      expect(await strategy.testGetTokens(cfmm)).to.deep.equal(cfmmTokens);
      expect(await strategy.testGetPoolId(cfmm)).to.equal(cfmmPoolId);
      expect(await pool.getNormalizedWeights()).to.deep.equal(WEIGHTS);
      expect(await strategy.testGetWeights()).to.deep.equal(WEIGHTS);
    });

    it("Check Initialisation Parameters for Decimals CFMM", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const baseRate = ONE.div(100);
      const factor = ONE.mul(4).div(100);
      const maxApy = ONE.mul(75).div(100);

      // Check strategy params are correct
      expect(await strategyDecimals.baseRate()).to.equal(baseRate);
      expect(await strategyDecimals.factor()).to.equal(factor);
      expect(await strategyDecimals.maxApy()).to.equal(maxApy);

      // Check the strategy parameters align
      const HUNDRETH = BigNumber.from(10).pow(16);
      const WEIGHTS = [
        BigNumber.from(20).mul(HUNDRETH),
        BigNumber.from(80).mul(HUNDRETH),
      ];

      expect(decimalsPool.address).to.equal(cfmmDecimals);
      expect(await strategyDecimals.getCFMM()).to.equal(cfmmDecimals);
      expect(await strategyDecimals.getCFMMReserves()).to.deep.equal([
        BigNumber.from(0),
        BigNumber.from(0),
      ]);
      expect(await strategyDecimals.testGetVault(cfmmDecimals)).to.equal(
        await pool.getVault()
      );
      expect(await strategyDecimals.testGetTokens(cfmmDecimals)).to.deep.equal(
        cfmmDecimalsTokens
      );
      expect(await strategyDecimals.testGetPoolId(cfmmDecimals)).to.equal(
        cfmmDecimalsPoolId
      );
      expect(await decimalsPool.getNormalizedWeights()).to.deep.equal(WEIGHTS);
      expect(await strategyDecimals.testGetWeights()).to.deep.equal(WEIGHTS);
    });

    describe("Repay Functions", function () {
      it("Calc Tokens to Repay", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const reserves0 = ONE.mul(500);
        const reserves1 = ONE.mul(1000);
        const lastCFMMInvariant = ONE.mul(1000);
        const liquidity = ONE.mul(100);
        await (
          await strategy.setCFMMReserves(
            reserves0,
            reserves1,
            lastCFMMInvariant
          )
        ).wait();
        const res0 = await strategy.testCalcTokensToRepay(liquidity);
        expect(res0[0]).to.equal(ONE.mul(50));
        expect(res0[1]).to.equal(ONE.mul(100));

        await (
          await strategy.setCFMMReserves(
            reserves0,
            reserves1.mul(2),
            lastCFMMInvariant
          )
        ).wait();
        const res1 = await strategy.testCalcTokensToRepay(liquidity);
        expect(res1[0]).to.equal(ONE.mul(50));
        expect(res1[1]).to.equal(ONE.mul(200));

        await (
          await strategy.setCFMMReserves(
            reserves0.mul(2),
            reserves1,
            lastCFMMInvariant
          )
        ).wait();
        const res2 = await strategy.testCalcTokensToRepay(liquidity);
        expect(res2[0]).to.equal(ONE.mul(100));
        expect(res2[1]).to.equal(ONE.mul(100));
      });

      it("Before Repay", async function () {
        // BeforeRepay now does nothing, hence should never revert

        const res1 = await (await strategy.createLoan()).wait();
        const tokenId = res1.events[0].args.tokenId;

        await (await tokenA.transfer(strategy.address, 100)).wait();
        await (await tokenB.transfer(strategy.address, 200)).wait();

        expect(await tokenA.balanceOf(strategy.address)).to.equal(100);
        expect(await tokenB.balanceOf(strategy.address)).to.equal(200);
        expect(await tokenA.balanceOf(cfmm)).to.equal(0);
        expect(await tokenB.balanceOf(cfmm)).to.equal(0);

        await (
          await strategy.setTokenBalances(tokenId, 100, 200, 100, 200)
        ).wait();

        await (await strategy.testBeforeRepay(tokenId, [100, 200])).wait();

        // The balances of these contracts should be unchanged
        expect(await tokenA.balanceOf(cfmm)).to.equal(0);
        expect(await tokenB.balanceOf(cfmm)).to.equal(0);
        expect(await tokenA.balanceOf(strategy.address)).to.equal(100);
        expect(await tokenB.balanceOf(strategy.address)).to.equal(200);

        await (await tokenA.transfer(strategy.address, 300)).wait();
        await (await tokenB.transfer(strategy.address, 140)).wait();

        expect(await tokenA.balanceOf(strategy.address)).to.equal(400);
        expect(await tokenB.balanceOf(strategy.address)).to.equal(340);
        expect(await tokenA.balanceOf(cfmm)).to.equal(0);
        expect(await tokenB.balanceOf(cfmm)).to.equal(0);
      });
    });

    describe("Get Amount In/Out", function () {
      it("Error GetAmountIn", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const WEIGHT0 = ONE.div(10);
        const WEIGHT1 = ONE.sub(WEIGHT0);

        const SCALINGFACTOR = BigNumber.from(1);

        await expect(
          strategy.testGetAmountIn(
            0,
            0,
            WEIGHT0,
            0,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#004"); // ZeroDivision error

        await expect(
          strategy.testGetAmountIn(
            1000000000,
            0,
            WEIGHT0,
            0,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#305"); // Token out unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountIn(
            1000000000,
            1000000000,
            WEIGHT0,
            0,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#305"); // Token out unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountIn(
            1000000000,
            0,
            WEIGHT0,
            1000000000,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#305"); // Token out unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountIn(
            40000,
            1000000000,
            WEIGHT0,
            1000000000,
            WEIGHT0,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL308"); // Pool weights don't add to 1

        await expect(
          strategy.testGetAmountIn(
            40000,
            1000000000,
            WEIGHT1,
            1000000000,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL308"); // Pool weights don't add to 1
      });

      it("Error GetAmountOut", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const WEIGHT0 = ONE.div(10);
        const WEIGHT1 = ONE.sub(WEIGHT0);

        const SCALINGFACTOR = BigNumber.from(1);

        await expect(
          strategy.testGetAmountOut(
            0,
            0,
            WEIGHT0,
            0,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#004"); // ZeroDivision error

        await expect(
          strategy.testGetAmountOut(
            1000000000,
            0,
            WEIGHT0,
            0,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#304"); // Token in unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountOut(
            1000000000,
            1000000000,
            WEIGHT0,
            0,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#304"); // Token in unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountOut(
            1000000000,
            0,
            WEIGHT0,
            1000000000,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL#304"); // Token in unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountOut(
            40000,
            1000000000,
            WEIGHT0,
            1000000000,
            WEIGHT0,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL308"); // Pool weights don't add to 1

        await expect(
          strategy.testGetAmountOut(
            40000,
            1000000000,
            WEIGHT1,
            1000000000,
            WEIGHT1,
            SCALINGFACTOR,
            SCALINGFACTOR
          )
        ).to.be.revertedWith("BAL308"); // Pool weights don't add to 1
      });

      it("Calculate GetAmountIn", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const amountOut = ONE.mul(100);
        const reserveOut = ONE.mul(500);
        const reserveIn = ONE.mul(1000);

        const WEIGHT0 = ONE.div(10);
        const WEIGHT1 = ONE.sub(WEIGHT0);

        const SCALINGFACTOR = BigNumber.from(1);

        const answer1 = await strategy.testGetAmountIn(
          amountOut,
          reserveOut,
          WEIGHT0,
          reserveIn,
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer1 = BigNumber.from("25357220663536529408");

        expectEqualWithError(answer1, expectedAnswer1);

        const answer2 = await strategy.testGetAmountIn(
          BigNumber.from(105).mul(ONE),
          reserveOut,
          WEIGHT0,
          reserveIn.mul(3),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer2 = BigNumber.from("80416298597382832128");

        expectEqualWithError(answer2, expectedAnswer2);

        const answer3 = await strategy.testGetAmountIn(
          amountOut.mul(2),
          reserveOut.mul(7),
          WEIGHT0,
          reserveIn.mul(3),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer3 = BigNumber.from("19876520058160660480");

        expectEqualWithError(answer3, expectedAnswer3);

        const answer4 = await strategy.testGetAmountIn(
          amountOut.mul(3),
          reserveOut.mul(7),
          WEIGHT0,
          reserveIn.mul(12),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer4 = BigNumber.from("121292623593009332224");

        expectEqualWithError(answer4, expectedAnswer4);

        const answer5 = await strategy.testGetAmountIn(
          amountOut.mul(2),
          reserveOut.mul(5),
          WEIGHT0,
          reserveIn.mul(3),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer5 = BigNumber.from("28205068727569096704");

        expectEqualWithError(answer5, expectedAnswer5);
      });

      it("Calculate GetAmountIn for Decimals", async function () {
        const ONE = BigNumber.from(10).pow(cfmmDecimalsTokenDecimals[0]);
        const DECIMALS_ONE = BigNumber.from(10).pow(
          cfmmDecimalsTokenDecimals[1]
        );

        const amountOut = ONE.mul(100);
        const reserveOut = ONE.mul(500);
        const reserveIn = DECIMALS_ONE.mul(1000);

        const WEIGHT0 = BigNumber.from(10).pow(18).div(10);
        const WEIGHT1 = BigNumber.from(10).pow(18).sub(WEIGHT0);

        const SCALINGFACTOR0 = BigNumber.from(10).pow(
          18 - cfmmDecimalsTokenDecimals[0]
        );
        const SCALINGFACTOR1 = BigNumber.from(10).pow(
          18 - cfmmDecimalsTokenDecimals[1]
        );

        const answer1 = await strategy.testGetAmountIn(
          amountOut,
          reserveOut,
          WEIGHT0,
          reserveIn,
          WEIGHT1,
          SCALINGFACTOR1,
          SCALINGFACTOR0
        );

        let expectedAnswer1 = BigNumber.from("25357220663536529408");

        if (cfmmDecimalsTokenDecimals[1] < 18) {
          expectedAnswer1 = expectedAnswer1.div(
            BigNumber.from(10).pow(18 - cfmmDecimalsTokenDecimals[1])
          );
        }

        expectEqualWithError(answer1, expectedAnswer1);
      });

      it("Calculate GetAmountOut", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const amountIn = ONE.mul(100);
        const reserveOut = ONE.mul(500);
        const reserveIn = ONE.mul(1000);

        const WEIGHT0 = ONE.div(10);
        const WEIGHT1 = ONE.sub(WEIGHT0);

        const SCALINGFACTOR = BigNumber.from(1);

        const amountOut1 = await strategy.testGetAmountOut(
          amountIn,
          reserveOut,
          WEIGHT0,
          reserveIn,
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer1 = BigNumber.from("287429996912549888000");

        expectEqualWithError(amountOut1, expectedAnswer1);

        const amountOut2 = await strategy.testGetAmountOut(
          amountIn.mul(2),
          reserveOut,
          WEIGHT0,
          reserveIn.mul(3),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer2 = BigNumber.from("219815289395209764864");

        expectEqualWithError(amountOut2, expectedAnswer2);

        const amountOut3 = await strategy.testGetAmountOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          WEIGHT0,
          reserveIn.mul(3),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer3 = BigNumber.from("1538707025766468550656");

        expectEqualWithError(amountOut3, expectedAnswer3);

        const amountOut4 = await strategy.testGetAmountOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          WEIGHT0,
          reserveIn.mul(19),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer4 = BigNumber.from("313884305967069986816");

        expectEqualWithError(amountOut4, expectedAnswer4);

        const amountOut5 = await strategy.testGetAmountOut(
          amountIn.mul(2),
          reserveOut.mul(2),
          WEIGHT0,
          reserveIn.mul(15),
          WEIGHT1,
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const expectedAnswer5 = BigNumber.from("112060590249046573056");

        expectEqualWithError(amountOut5, expectedAnswer5);
      });

      it("Calculate GetAmountOut for Decimals", async function () {
        const ONE = BigNumber.from(10).pow(cfmmDecimalsTokenDecimals[0]);
        const ONE2 = BigNumber.from(10).pow(cfmmDecimalsTokenDecimals[1]);

        const amountIn = ONE2.mul(100);

        const reserveOut = ONE.mul(500);
        const reserveIn = ONE2.mul(1000);

        const weightOut = BigNumber.from(10).pow(17);
        const weightIn = BigNumber.from(10).pow(18).sub(weightOut);

        const SCALINGFACTOR0 = BigNumber.from(10).pow(
          18 - cfmmDecimalsTokenDecimals[0]
        );
        const SCALINGFACTOR1 = BigNumber.from(10).pow(
          18 - cfmmDecimalsTokenDecimals[1]
        );

        const amountOut1 = await strategy.testGetAmountOut(
          amountIn,
          reserveOut,
          weightOut,
          reserveIn,
          weightIn,
          SCALINGFACTOR1,
          SCALINGFACTOR0
        );

        let expectedAnswer1 = BigNumber.from("287429996912549888000");

        if (cfmmDecimalsTokenDecimals[0] < 18) {
          expectedAnswer1 = expectedAnswer1.div(
            BigNumber.from(10).pow(18 - cfmmDecimalsTokenDecimals[0])
          );
        }

        expectEqualWithError(amountOut1, expectedAnswer1);
      });
    });

    describe("Calculate Tokens to Swap", function () {
      it("Error Before Token Swap", async function () {
        const res1 = await (await strategy.createLoan()).wait();
        const tokenId = res1.events[0].args.tokenId;

        await expect(
          strategy.testBeforeSwapTokens(tokenId, [0, 0])
        ).to.be.revertedWith("BadDelta");

        await expect(
          strategy.testBeforeSwapTokens(tokenId, [1, 1])
        ).to.be.revertedWith("BadDelta");

        await expect(
          strategy.testBeforeSwapTokens(tokenId, [-1, -1])
        ).to.be.revertedWith("BadDelta");

        await expect(
          strategy.testBeforeSwapTokens(tokenId, [1, -1])
        ).to.be.revertedWith("BadDelta");

        await expect(
          strategy.testBeforeSwapTokens(tokenId, [-1, 1])
        ).to.be.revertedWith("BadDelta");
      });

      it("Calculate Exact Tokens to Buy", async function () {
        const res = await (await strategy.createLoan()).wait();
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);

        const SCALINGFACTOR = BigNumber.from(1);

        // Buy exactly delta
        const res0 = await (
          await strategy.testBeforeSwapTokens(tokenId, [delta, 0])
        ).wait();

        const evt0 = res0.events[res0.events.length - 1];

        const amtOut0 = await strategy.testGetAmountIn(
          delta,
          reserves0,
          WEIGHTS[0],
          reserves1,
          WEIGHTS[1],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        expectEqualWithError(evt0.args.inAmts[0], delta);
        expect(evt0.args.inAmts[1]).to.equal(0);
        expect(evt0.args.outAmts[0]).to.equal(0);
        expectEqualWithError(evt0.args.outAmts[1], amtOut0);

        // Buy exactly delta
        const res1 = await (
          await strategy.testBeforeSwapTokens(tokenId, [0, delta])
        ).wait();

        const evt1 = res1.events[res1.events.length - 1];
        const amtOut1 = await strategy.testGetAmountIn(
          delta,
          reserves1,
          WEIGHTS[1],
          reserves0,
          WEIGHTS[0],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        expect(evt1.args.inAmts[0]).to.equal(0);
        expectEqualWithError(evt1.args.inAmts[1], delta);
        expectEqualWithError(evt1.args.outAmts[0], amtOut1);
        expect(evt1.args.outAmts[1]).to.equal(0);
      });

      it("Calculate Exact Tokens to Sell", async function () {
        const res = await (await strategy.createLoan()).wait();
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);
        const negDelta = ethers.constants.Zero.sub(delta);

        const SCALINGFACTOR = BigNumber.from(1);

        // Sell exactly delta
        const res0 = await (
          await strategy.testBeforeSwapTokens(tokenId, [negDelta, 0])
        ).wait();

        const evt0 = res0.events[res0.events.length - 1];

        const amtIn0 = await strategy.testGetAmountOut(
          delta,
          reserves1,
          WEIGHTS[1],
          reserves0,
          WEIGHTS[0],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        expect(evt0.args.inAmts[0]).to.equal(0);
        expectEqualWithError(evt0.args.inAmts[1], amtIn0);
        expectEqualWithError(evt0.args.outAmts[0], delta);
        expect(evt0.args.outAmts[1]).to.equal(0);

        // Sell exactly delta
        const res1 = await (
          await strategy.testBeforeSwapTokens(tokenId, [0, negDelta])
        ).wait();
        const evt1 = res1.events[res1.events.length - 1];

        const amtIn1 = await strategy.testGetAmountOut(
          delta,
          reserves0,
          WEIGHTS[0],
          reserves1,
          WEIGHTS[1],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        expectEqualWithError(evt1.args.inAmts[0], amtIn1);
        expect(evt1.args.inAmts[1]).to.equal(0);
        expect(evt1.args.outAmts[0]).to.equal(0);
        expectEqualWithError(evt1.args.outAmts[1], delta);
      });
    });

    describe("Swap Tokens", function () {
      async function getStrategyReserves(_strategy: any, _tokens: any) {
        let tokens0Balance;
        let tokens1Balance;

        if (
          BigNumber.from(_tokens[0].address).lt(
            BigNumber.from(_tokens[1].address)
          )
        ) {
          tokens0Balance = await _tokens[0].balanceOf(_strategy.address);
          tokens1Balance = await _tokens[1].balanceOf(_strategy.address);
        } else {
          tokens0Balance = await _tokens[1].balanceOf(_strategy.address);
          tokens1Balance = await _tokens[0].balanceOf(_strategy.address);
        }
        return { tokens0: tokens0Balance, tokens1: tokens1Balance };
      }

      it("Swap Tokens for Exact Tokens, First Index", async function () {
        // Create a loan in the Long Strategy
        const res = await (await strategy.createLoan()).wait();
        // Get the loan token ID
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);

        // Reserves of the Balancer pool
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);

        const SCALINGFACTOR = BigNumber.from(1);

        // Calculated the expected amount out
        const expAmtOut0 = await strategy.testGetAmountIn(
          delta,
          reserves0,
          WEIGHTS[0],
          reserves1,
          WEIGHTS[1],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const strategyReserves0 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        // delta tokens are added to the strategy in slot 0 and expAmtOut0 tokens are removed from the strategy in slot 1
        const res0 = await (
          await strategy.testSwapTokens(tokenId, [delta, 0])
        ).wait();

        const strategyReserves1 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        // Check that the event arguments are correct
        const evt0 = res0.events[res0.events.length - 1];

        expect(evt0.args.outAmts[0]).to.equal(0);
        expectEqualWithError(evt0.args.outAmts[1], expAmtOut0);
        expectEqualWithError(evt0.args.inAmts[0], delta);
        expect(evt0.args.inAmts[1]).to.equal(0);

        expectEqualWithError(
          strategyReserves1.tokens0,
          strategyReserves0.tokens0.add(delta)
        );

        expectEqualWithError(
          strategyReserves1.tokens1,
          strategyReserves0.tokens1.sub(expAmtOut0)
        );

        await (
          await strategy.setCFMMReserves(
            reserves0.sub(delta),
            reserves1.add(expAmtOut0),
            0
          )
        ).wait();

        const strategyReserves2 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        const expAmtOut1 = await strategy.testGetAmountIn(
          delta,
          reserves1.add(expAmtOut0),
          WEIGHTS[1],
          reserves0.sub(delta),
          WEIGHTS[0],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        // Swap where delta tokens are added in slot 1 and some amountIn is removed from slot 0
        const res1 = await (
          await strategy.testSwapTokens(tokenId, [0, delta])
        ).wait();

        const strategyReserves3 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        const evt1 = res1.events[res1.events.length - 1];

        expectEqualWithError(evt1.args.outAmts[0], expAmtOut1);
        expect(evt1.args.outAmts[1]).to.equal(0);
        expect(evt1.args.inAmts[0]).to.equal(0);
        expectEqualWithError(evt1.args.inAmts[1], delta);

        expectEqualWithError(
          strategyReserves3.tokens0,
          strategyReserves2.tokens0.sub(expAmtOut1)
        );

        expectEqualWithError(
          strategyReserves3.tokens1,
          strategyReserves2.tokens1.add(delta)
        );
      });

      it("Swap Tokens for Exact Tokens, Second Index", async function () {
        // Create a loan in the Long Strategy
        const res = await (await strategy.createLoan()).wait();
        // Get the loan token ID
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);

        // Reserves of the Balancer pool
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);

        const SCALINGFACTOR = BigNumber.from(1);

        const expAmtOut1 = await strategy.testGetAmountIn(
          delta,
          reserves1,
          WEIGHTS[1],
          reserves0,
          WEIGHTS[0],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        const strategyReserves = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        // Swap where delta tokens are added in slot 1 and some amountIn is removed from slot 0
        const res1 = await (
          await strategy.testSwapTokens(tokenId, [0, delta])
        ).wait();

        const strategyReserves2 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        const evt1 = res1.events[res1.events.length - 1];

        expectEqualWithError(evt1.args.outAmts[0], expAmtOut1);
        expect(evt1.args.outAmts[1]).to.equal(0);
        expect(evt1.args.inAmts[0]).to.equal(0);
        expectEqualWithError(evt1.args.inAmts[1], delta);

        expectEqualWithError(
          strategyReserves2.tokens0,
          strategyReserves.tokens0.sub(expAmtOut1)
        );

        expectEqualWithError(
          strategyReserves2.tokens1,
          strategyReserves.tokens1.add(delta)
        );
      });

      it("Swap Exact Tokens for Tokens, First Index", async function () {
        const res = await (await strategy.createLoan()).wait();
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);
        const negDelta = ethers.constants.Zero.sub(delta);

        const SCALINGFACTOR = BigNumber.from(1);

        const strategyReserves0 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        const expectedAmountOut0 = await strategy.testGetAmountOut(
          delta,
          reserves1,
          WEIGHTS[1],
          reserves0,
          WEIGHTS[0],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        // delta tokens are leaving the GammaPool in slot 0 and expectedAmountOut0 tokens are entering the GammaPool in slot 1
        const res0 = await (
          await strategy.testSwapTokens(tokenId, [negDelta, 0])
        ).wait();

        const strategyReserves1 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        const evt0 = res0.events[res0.events.length - 1];
        expect(evt0.args.outAmts[0]).to.equal(delta);
        expect(evt0.args.outAmts[1]).to.equal(0);
        expect(evt0.args.inAmts[0]).to.equal(0);
        expect(evt0.args.inAmts[1]).to.equal(expectedAmountOut0);

        expectEqualWithError(
          strategyReserves1.tokens0,
          strategyReserves0.tokens0.sub(delta)
        );

        expectEqualWithError(
          strategyReserves1.tokens1,
          strategyReserves0.tokens1.add(expectedAmountOut0)
        );

        const actualStrategyReserves1 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        await (
          await strategy.setCFMMReserves(
            strategyReserves0.tokens0.sub(delta),
            strategyReserves0.tokens1.add(expectedAmountOut0),
            0
          )
        ).wait();

        const strategyReserves2 = await strategy.getCFMMReserves();

        expectEqualWithError(
          actualStrategyReserves1.tokens0,
          strategyReserves2[0]
        );
        expectEqualWithError(
          actualStrategyReserves1.tokens1,
          strategyReserves2[1]
        );
      });

      it("Swap Exact Tokens for Tokens, Second Index", async function () {
        const res = await (await strategy.createLoan()).wait();
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);
        const negDelta = ethers.constants.Zero.sub(delta);

        const SCALINGFACTOR = BigNumber.from(1);

        const strategyReserves0 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        const expectedAmountOut0 = await strategy.testGetAmountOut(
          delta,
          reserves0,
          WEIGHTS[0],
          reserves1,
          WEIGHTS[1],
          SCALINGFACTOR,
          SCALINGFACTOR
        );

        // delta tokens are leaving the GammaPool in slot 1 and expectedAmountOut0 tokens are entering the GammaPool in slot 0
        const res0 = await (
          await strategy.testSwapTokens(tokenId, [0, negDelta])
        ).wait();

        const strategyReserves1 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        const evt0 = res0.events[res0.events.length - 1];
        expect(evt0.args.outAmts[0]).to.equal(0);
        expect(evt0.args.outAmts[1]).to.equal(delta);
        expect(evt0.args.inAmts[0]).to.equal(expectedAmountOut0);
        expect(evt0.args.inAmts[1]).to.equal(0);

        expectEqualWithError(
          strategyReserves1.tokens1,
          strategyReserves0.tokens1.sub(delta)
        );

        expectEqualWithError(
          strategyReserves1.tokens0,
          strategyReserves0.tokens0.add(expectedAmountOut0)
        );

        const actualStrategyReserves1 = await getStrategyReserves(strategy, [
          tokenA,
          tokenB,
        ]);

        await (
          await strategy.setCFMMReserves(
            strategyReserves0.tokens0.add(expectedAmountOut0),
            strategyReserves0.tokens1.sub(delta),
            0
          )
        ).wait();

        const strategyReserves2 = await strategy.getCFMMReserves();

        expectEqualWithError(
          actualStrategyReserves1.tokens0,
          strategyReserves2[0]
        );

        expectEqualWithError(
          actualStrategyReserves1.tokens1,
          strategyReserves2[1]
        );
      });
    });
  });
});
