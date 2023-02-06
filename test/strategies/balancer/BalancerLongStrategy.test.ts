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
  let TestStrategy: any;
  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let WeightedPool: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let vault: any;
  let factory: any;
  let strategy: any;
  let owner: any;
  let pool: any;
  let poolId: any;
  let weightedMathFactory: any;
  let weightedMath: any;

  let TOKENS: any;
  let WEIGHTS: any;

  beforeEach(async function () {
    weightedMathFactory = await ethers.getContractFactory("WeightedMath");
    weightedMath = await weightedMathFactory.deploy();

    TestERC20 = await ethers.getContractFactory("TestERC20");
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

    TestStrategy = await ethers.getContractFactory("TestBalancerLongStrategy", {
      libraries: { WeightedMath: weightedMath.address },
    });

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

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
    cfmm = await createPair(tokenA, tokenB);

    pool = WeightedPool.attach(cfmm);
    poolId = await pool.getPoolId();

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);
    const tradingFee1 = 990;
    const tradingFee2 = 1000;

    strategy = await TestStrategy.deploy(
      0,
      tradingFee1,
      tradingFee2,
      baseRate,
      factor,
      maxApy
    );

    // uint16 _originationFee, uint16 _tradingFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy

    await (await strategy.initialize(cfmm, TOKENS, [18, 18])).wait();
  });

  // function calcAmtIn(
  //   amountOut: BigNumber,
  //   reserveOut: BigNumber,
  //   reserveIn: BigNumber,
  //   tradingFee1: any,
  //   tradingFee2: any
  // ): BigNumber {
  //   const amountOutWithFee = amountOut.mul(tradingFee1);
  //   const denominator = reserveOut.mul(tradingFee2).add(amountOutWithFee);
  //   return amountOutWithFee.mul(reserveIn).div(denominator);
  // }

  // function calcAmtOut(
  //   amountIn: BigNumber,
  //   reserveOut: BigNumber,
  //   reserveIn: BigNumber,
  //   tradingFee1: any,
  //   tradingFee2: any
  // ): BigNumber {
  //   const denominator = reserveIn.sub(amountIn).mul(tradingFee1);
  //   const num = reserveOut.mul(amountIn).mul(tradingFee2).div(denominator);
  //   return num.add(1);
  // }

  // async function setUpStrategyAndCFMM(tokenId: any, hasFee: any) {
  //   const ONE = BigNumber.from(10).pow(18);

  //   if (hasFee) {
  //     strategy = strategyFee;
  //     tokenA = tokenAFee;
  //     tokenB = tokenBFee;
  //     cfmm = cfmmFee;
  //   }

  //   const collateral0 = ONE.mul(100);
  //   const collateral1 = ONE.mul(200);
  //   const balance0 = ONE.mul(1000);
  //   const balance1 = ONE.mul(2000);

  //   await (await tokenA.transfer(strategy.address, balance0)).wait();
  //   await (await tokenB.transfer(strategy.address, balance1)).wait();

  //   await (
  //     await strategy.setTokenBalances(
  //       tokenId,
  //       collateral0,
  //       collateral1,
  //       balance0,
  //       balance1
  //     )
  //   ).wait();

  //   await (await tokenA.transfer(cfmm.address, ONE.mul(5000))).wait();
  //   await (await tokenB.transfer(cfmm.address, ONE.mul(10000))).wait();
  //   await (await cfmm.sync()).wait();

  //   const rez = await cfmm.getReserves();
  //   const reserves0 = rez._reserve0;
  //   const reserves1 = rez._reserve1;

  //   await (await strategy.setCFMMReserves(reserves0, reserves1, 0)).wait();

  //   return { res0: reserves0, res1: reserves1 };
  // }

  async function createPair(token1: any, token2: any) {
    const NAME = "TESTPOOL";
    const SYMBOL = "TP";
    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      TOKENS = [token2.address, token1.address];
    } else {
      TOKENS = [token1.address, token2.address];
    }
    const HUNDRETH = BigNumber.from(10).pow(16);
    WEIGHTS = [
      BigNumber.from(50).mul(HUNDRETH),
      BigNumber.from(50).mul(HUNDRETH),
    ];
    const FEE_PERCENTAGE = HUNDRETH;

    const poolReturnData = await factory.create(
      NAME,
      SYMBOL,
      TOKENS,
      WEIGHTS,
      FEE_PERCENTAGE,
      owner.address
    );

    const receipt = await poolReturnData.wait();

    const events = receipt.events.filter((e: any) => e.event === "PoolCreated");

    const poolAddress = events[0].args.pool;

    return poolAddress;
  }

  function expectEqualWithError(actual: BigNumber, expected: BigNumber) {
    const error = actual.sub(expected).abs();
    expect(error.mul(100000).div(expected).lte(1000)).to.be.equal(true);
  }

  async function initialisePool(initialBalances: any) {
    // We must perform an INIT join at the beginning to start the pool
    const JOIN_KIND_INIT = 0;
    const initUserData = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "uint256[]"],
      [JOIN_KIND_INIT, initialBalances]
    );

    // 'ERC20: insufficient allowance'
    // We must approve the vault to spend the tokens we own
    await tokenA.approve(vault.address, ethers.constants.MaxUint256);
    await tokenB.approve(vault.address, ethers.constants.MaxUint256);

    const joinPoolRequest = {
      assets: TOKENS,
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
    const balance0 = ONE.mul(1000);
    const balance1 = ONE.mul(2000);

    await (await tokenA.transfer(strategy.address, balance0)).wait();
    await (await tokenB.transfer(strategy.address, balance1)).wait();

    await (
      await strategy.setTokenBalances(
        tokenId,
        collateral0,
        collateral1,
        balance0,
        balance1
      )
    ).wait();

    await initialisePool([ONE.mul(5000), ONE.mul(10000)]);
    const reserves = await strategy.testGetPoolReserves(cfmm);

    const reserves0 = reserves[0];
    const reserves1 = reserves[1];
    await (await strategy.setCFMMReserves(reserves0, reserves1, 0)).wait();

    return { reserves0: reserves0, reserves1: reserves1 };
  }

  describe("Deployment", function () {
    it("Check Init Params", async function () {
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
        BigNumber.from(50).mul(HUNDRETH),
        BigNumber.from(50).mul(HUNDRETH),
      ];

      expect(pool.address).to.equal(cfmm);
      expect(await strategy.getCFMM()).to.equal(cfmm);
      expect(await strategy.getCFMMReserves()).to.deep.equal([
        BigNumber.from(0),
        BigNumber.from(0),
      ]);
      expect(await strategy.testGetVault(cfmm)).to.equal(await pool.getVault());
      expect(await strategy.testGetTokens(cfmm)).to.deep.equal(TOKENS);
      expect(await strategy.testGetPoolId(cfmm)).to.equal(poolId);
      expect(await pool.getNormalizedWeights()).to.deep.equal(WEIGHTS);
      expect(await strategy.testGetWeights(cfmm)).to.deep.equal(WEIGHTS);
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

      // BeforeRepay now does nothing, hence should never revert
      // it.skip("Error Before Repay", async function () {
      //   const ONE = BigNumber.from(10).pow(18);

      //   const res1 = await (await strategy.createLoan()).wait();
      //   const tokenId = res1.events[0].args.tokenId;

      //   await expect(
      //     strategy.testBeforeRepay(tokenId, [1, 1])
      //   ).to.be.revertedWith("NotEnoughBalance");

      //   expect(await tokenA.balanceOf(cfmm)).to.equal(0);
      //   expect(await tokenB.balanceOf(cfmm)).to.equal(0);

      //   await (await strategy.setTokenBalances(tokenId, 10, 10, 100, 10)).wait();

      //   await expect(
      //     strategy.testBeforeRepay(tokenId, [11, 1])
      //   ).to.be.revertedWith("NotEnoughCollateral");

      //   expect(await tokenA.balanceOf(cfmm)).to.equal(0);
      //   expect(await tokenB.balanceOf(cfmm)).to.equal(0);

      //   const amtA = ONE.mul(100);
      //   const amtB = ONE.mul(200);

      //   await (await tokenA.transfer(strategy.address, amtA)).wait();
      //   await (await tokenB.transfer(strategy.address, amtB)).wait();

      //   await expect(
      //     strategy.testBeforeRepay(tokenId, [1, 11])
      //   ).to.be.revertedWith("NotEnoughBalance");

      //   expect(await tokenA.balanceOf(cfmm)).to.equal(0);
      //   expect(await tokenB.balanceOf(cfmm)).to.equal(0);

      //   await (await strategy.setTokenBalances(tokenId, 10, 10, 100, 11)).wait();

      //   await expect(
      //     strategy.testBeforeRepay(tokenId, [1, 11])
      //   ).to.be.revertedWith("NotEnoughCollateral");

      //   expect(await tokenA.balanceOf(cfmm)).to.equal(0);
      //   expect(await tokenB.balanceOf(cfmm)).to.equal(0);
      // });

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
        // TODO: Is this unit test redundant?
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
        const WEIGHT1 = ONE.div(10);
        const WEIGHT2 = ONE.sub(WEIGHT1);

        await expect(
          strategy.testGetAmountIn(0, 0, WEIGHT1, 0, WEIGHT2)
        ).to.be.revertedWith("BAL#004"); // ZeroDivision error

        await expect(
          strategy.testGetAmountIn(1000000000, 0, WEIGHT1, 0, WEIGHT2)
        ).to.be.revertedWith("BAL#305"); // Token out unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountIn(1000000000, 1000000000, WEIGHT1, 0, WEIGHT2)
        ).to.be.revertedWith("BAL#305"); // Token out unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountIn(1000000000, 0, WEIGHT1, 1000000000, WEIGHT2)
        ).to.be.revertedWith("BAL#305"); // Token out unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountIn(
            40000,
            1000000000,
            WEIGHT1,
            1000000000,
            WEIGHT1
          )
        ).to.be.revertedWith("BAL#308"); // Pool weights don't add to 1

        await expect(
          strategy.testGetAmountIn(
            40000,
            1000000000,
            WEIGHT2,
            1000000000,
            WEIGHT2
          )
        ).to.be.revertedWith("BAL#308"); // Pool weights don't add to 1
      });

      it("Error GetAmountOut", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const WEIGHT1 = ONE.div(10);
        const WEIGHT2 = ONE.sub(WEIGHT1);

        await expect(
          strategy.testGetAmountOut(0, 0, WEIGHT1, 0, WEIGHT2)
        ).to.be.revertedWith("BAL#004"); // ZeroDivision error

        await expect(
          strategy.testGetAmountOut(1000000000, 0, WEIGHT1, 0, WEIGHT2)
        ).to.be.revertedWith("BAL#304"); // Token in unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountOut(1000000000, 1000000000, WEIGHT1, 0, WEIGHT2)
        ).to.be.revertedWith("BAL#304"); // Token in unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountOut(1000000000, 0, WEIGHT1, 1000000000, WEIGHT2)
        ).to.be.revertedWith("BAL#304"); // Token in unbalanced the pool too much on a swap

        await expect(
          strategy.testGetAmountOut(
            40000,
            1000000000,
            WEIGHT1,
            1000000000,
            WEIGHT1
          )
        ).to.be.revertedWith("BAL#308"); // Pool weights don't add to 1

        await expect(
          strategy.testGetAmountOut(
            40000,
            1000000000,
            WEIGHT2,
            1000000000,
            WEIGHT2
          )
        ).to.be.revertedWith("BAL#308"); // Pool weights don't add to 1
      });

      it("Calculate GetAmountIn", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const amountOut = ONE.mul(100);
        const reserveOut = ONE.mul(500);
        const reserveIn = ONE.mul(1000);

        const WEIGHT1 = ONE.div(10);
        const WEIGHT2 = ONE.sub(WEIGHT1);

        const answer1 = await strategy.testGetAmountIn(
          amountOut,
          reserveOut,
          WEIGHT1,
          reserveIn,
          WEIGHT2
        );

        const expectedAnswer1 = BigNumber.from("25357220663536529408");

        expectEqualWithError(answer1, expectedAnswer1);

        const answer2 = await strategy.testGetAmountIn(
          BigNumber.from(105).mul(ONE),
          reserveOut,
          WEIGHT1,
          reserveIn.mul(3),
          WEIGHT2
        );

        const expectedAnswer2 = BigNumber.from("80416298597382832128");

        expectEqualWithError(answer2, expectedAnswer2);

        const answer3 = await strategy.testGetAmountIn(
          amountOut.mul(2),
          reserveOut.mul(7),
          WEIGHT1,
          reserveIn.mul(3),
          WEIGHT2
        );

        const expectedAnswer3 = BigNumber.from("19876520058160660480");

        expectEqualWithError(answer3, expectedAnswer3);

        const answer4 = await strategy.testGetAmountIn(
          amountOut.mul(3),
          reserveOut.mul(7),
          WEIGHT1,
          reserveIn.mul(12),
          WEIGHT2
        );

        const expectedAnswer4 = BigNumber.from("121292623593009332224");

        expectEqualWithError(answer4, expectedAnswer4);

        const answer5 = await strategy.testGetAmountIn(
          amountOut.mul(2),
          reserveOut.mul(5),
          WEIGHT1,
          reserveIn.mul(3),
          WEIGHT2
        );

        const expectedAnswer5 = BigNumber.from("28205068727569096704");

        expectEqualWithError(answer5, expectedAnswer5);
      });

      it.skip("Calculate GetAmountOut", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const amountIn = ONE.mul(100);
        const reserveOut = ONE.mul(500);
        const reserveIn = ONE.mul(1000);

        const amtIn1a = await strategy.testCalcAmtOut(
          amountIn,
          reserveOut,
          reserveIn
        );
        const amtIn1b = calcAmtOut(amountIn, reserveOut, reserveIn, 997, 1000);
        expect(amtIn1a).to.equal(amtIn1b);

        const amtIn2a = await strategy.testCalcAmtOut(
          amountIn.mul(2),
          reserveOut,
          reserveIn.mul(3)
        );
        const amtIn2b = calcAmtOut(
          amountIn.mul(2),
          reserveOut,
          reserveIn.mul(3),
          997,
          1000
        );
        expect(amtIn2a).to.equal(amtIn2b);

        const amtIn3a = await strategy.testCalcAmtOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          reserveIn.mul(3)
        );
        const amtIn3b = calcAmtOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          reserveIn.mul(3),
          997,
          1000
        );
        expect(amtIn3a).to.equal(amtIn3b);

        const amtIn4a = await strategy.testCalcAmtOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          reserveIn.mul(3)
        );
        const amtIn4b = calcAmtOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          reserveIn.mul(3),
          998,
          1000
        );
        expect(amtIn4a).gt(amtIn4b);

        const amtIn5a = await strategy.testCalcAmtOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          reserveIn.mul(3)
        );
        const amtIn5b = calcAmtOut(
          amountIn.mul(2),
          reserveOut.mul(7),
          reserveIn.mul(3),
          996,
          1000
        );
        expect(amtIn5a).lt(amtIn5b);
      });

      // it.skip("Error Calc Actual Out Amount", async function () {
      //   const ONE = BigNumber.from(10).pow(18);
      //   const amt = ONE.mul(100);
      //   await expect(
      //     strategy.testCalcActualOutAmount(
      //       tokenA.address,
      //       addr1.address,
      //       amt,
      //       amt.sub(1),
      //       amt
      //     )
      //   ).to.be.revertedWith("NotEnoughBalance");
      //   await expect(
      //     strategy.testCalcActualOutAmount(
      //       tokenA.address,
      //       addr1.address,
      //       amt,
      //       amt,
      //       amt.sub(1)
      //     )
      //   ).to.be.revertedWith("NotEnoughCollateral");
      // });

      // it.skip("Calc Actual Out Amount", async function () {
      //   const ONE = BigNumber.from(10).pow(18);
      //   const amt = ONE.mul(100);

      //   await (await tokenA.transfer(strategy.address, amt)).wait();
      //   await (await tokenA.transfer(addr1.address, amt)).wait();

      //   const balance0 = await tokenA.balanceOf(addr1.address);
      //   const res = await (
      //     await strategy.testCalcActualOutAmount(
      //       tokenA.address,
      //       addr1.address,
      //       amt,
      //       amt,
      //       amt
      //     )
      //   ).wait();
      //   const evt = res.events[res.events.length - 1];
      //   expect(evt.args.outAmount).to.equal(amt);

      //   const balance1 = await tokenA.balanceOf(addr1.address);
      //   expect(evt.args.outAmount).to.equal(balance1.sub(balance0));
      // });
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
          WEIGHTS[1]
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
          WEIGHTS[0]
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
          WEIGHTS[0]
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
          WEIGHTS[1]
        );

        expectEqualWithError(evt1.args.inAmts[0], amtIn1);
        expect(evt1.args.inAmts[1]).to.equal(0);
        expect(evt1.args.outAmts[0]).to.equal(0);
        expectEqualWithError(evt1.args.outAmts[1], delta);
      });

      // it("Calc Exact Tokens with Fees to Buy", async function () {
      //   await createStrategy(true, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const fee = BigNumber.from(10).pow(16);

      //   // buy exactly delta
      //   const res0 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [delta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      //   const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      //   const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);
      //   expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.inAmts[1]).to.equal(0);
      //   expect(evt0.args.outAmts[0]).to.equal(0);
      //   expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);

      //   // buy exactly delta
      //   const res1 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [0, delta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   const amtOut1 = calcAmtOut(delta, reserves0, reserves1, 997, 1000);
      //   const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      //   const deltaFee1 = calcAmtIn(amtOut1Fee, reserves0, reserves1, 997, 1000);
      //   expect(evt1.args.inAmts[0]).to.equal(0);
      //   expect(evt1.args.inAmts[1]).to.equal(deltaFee1);
      //   expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      //   expect(evt1.args.outAmts[1]).to.equal(0);
      // });

      // it("Calc Exact Tokens with Fees to Sell", async function () {
      //   await createStrategy(true, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const negDelta = ethers.constants.Zero.sub(delta);
      //   const fee = BigNumber.from(10).pow(16);

      //   // sell exactly delta
      //   const res0 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [negDelta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);
      //   expect(evt0.args.inAmts[0]).to.equal(0);
      //   expect(evt0.args.inAmts[1]).to.equal(amtIn0);
      //   expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.outAmts[1]).to.equal(0);

      //   // sell exactly delta
      //   const res1 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [0, negDelta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn1 = calcAmtIn(deltaFee0, reserves1, reserves0, 997, 1000);
      //   expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      //   expect(evt1.args.inAmts[1]).to.equal(0);
      //   expect(evt1.args.outAmts[0]).to.equal(0);
      //   expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
      // });

      // it("Calc Exact Tokens A with Fees to Buy", async function () {
      //   await createStrategy(true, false);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const fee = BigNumber.from(10).pow(16);

      //   // buy exactly delta
      //   const res0 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [delta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      //   expect(evt0.args.inAmts[0]).to.equal(delta);
      //   expect(evt0.args.inAmts[1]).to.equal(0);
      //   expect(evt0.args.outAmts[0]).to.equal(0);
      //   expect(evt0.args.outAmts[1]).to.equal(amtOut0);

      //   // buy exactly delta
      //   const res1 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [0, delta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   const amtOut1 = calcAmtOut(delta, reserves0, reserves1, 997, 1000);
      //   const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      //   const deltaFee1 = calcAmtIn(amtOut1Fee, reserves0, reserves1, 997, 1000);
      //   expect(evt1.args.inAmts[0]).to.equal(0);
      //   expect(evt1.args.inAmts[1]).to.equal(deltaFee1);
      //   expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      //   expect(evt1.args.outAmts[1]).to.equal(0);
      // });

      // it("Calc Exact Tokens A with Fees to Sell", async function () {
      //   await createStrategy(true, false);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const negDelta = ethers.constants.Zero.sub(delta);
      //   const fee = BigNumber.from(10).pow(16);

      //   // sell exactly delta
      //   const res0 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [negDelta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);
      //   expect(evt0.args.inAmts[0]).to.equal(0);
      //   expect(evt0.args.inAmts[1]).to.equal(amtIn0);
      //   expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.outAmts[1]).to.equal(0);

      //   // sell exactly delta
      //   const res1 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [0, negDelta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   const amtIn1 = calcAmtIn(delta, reserves1, reserves0, 997, 1000);
      //   expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      //   expect(evt1.args.inAmts[1]).to.equal(0);
      //   expect(evt1.args.outAmts[0]).to.equal(0);
      //   expect(evt1.args.outAmts[1]).to.equal(delta);
      // });

      // it("Calc Exact Tokens B with Fees to Buy", async function () {
      //   await createStrategy(false, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const fee = BigNumber.from(10).pow(16);

      //   // buy exactly delta
      //   const res0 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [delta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      //   const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      //   const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);
      //   expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.inAmts[1]).to.equal(0);
      //   expect(evt0.args.outAmts[0]).to.equal(0);
      //   expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);

      //   // buy exactly delta
      //   const res1 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [0, delta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   const amtOut1 = calcAmtOut(delta, reserves0, reserves1, 997, 1000);
      //   expect(evt1.args.inAmts[0]).to.equal(0);
      //   expect(evt1.args.inAmts[1]).to.equal(delta);
      //   expect(evt1.args.outAmts[0]).to.equal(amtOut1);
      //   expect(evt1.args.outAmts[1]).to.equal(0);
      // });

      // it("Calc Exact Tokens B with Fees to Sell", async function () {
      //   await createStrategy(false, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const negDelta = ethers.constants.Zero.sub(delta);
      //   const fee = BigNumber.from(10).pow(16);

      //   // sell exactly delta
      //   const res0 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [negDelta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   const amtIn0 = calcAmtIn(delta, reserves0, reserves1, 997, 1000);
      //   expect(evt0.args.inAmts[0]).to.equal(0);
      //   expect(evt0.args.inAmts[1]).to.equal(amtIn0);
      //   expect(evt0.args.outAmts[0]).to.equal(delta);
      //   expect(evt0.args.outAmts[1]).to.equal(0);

      //   // sell exactly delta
      //   const res1 = await (
      //     await strategyFee.testBeforeSwapTokens(tokenId, [0, negDelta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn1 = calcAmtIn(deltaFee1, reserves1, reserves0, 997, 1000);
      //   expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      //   expect(evt1.args.inAmts[1]).to.equal(0);
      //   expect(evt1.args.outAmts[0]).to.equal(0);
      //   expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
      // });
    });

    describe("Swap Tokens", function () {
      async function getStrategyReserves() {
        let tokens0Balance;
        let tokens1Balance;

        if (TOKENS[0] === tokenB.address) {
          tokens0Balance = await tokenB.balanceOf(strategy.address);
          tokens1Balance = await tokenA.balanceOf(strategy.address);
        } else {
          tokens0Balance = await tokenA.balanceOf(strategy.address);
          tokens1Balance = await tokenB.balanceOf(strategy.address);
        }
        return { tokens0: tokens0Balance, tokens1: tokens1Balance };
      }

      it("Swap Tokens for Exact Tokens", async function () {
        const res = await (await strategy.createLoan()).wait();
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);

        const strategyReserves0 = await getStrategyReserves();

        const expAmtOut0 = await strategy.testGetAmountIn(
          delta,
          reserves0,
          WEIGHTS[0],
          reserves1,
          WEIGHTS[1]
        );

        const res0 = await (
          await strategy.testSwapTokens(tokenId, [delta, 0])
        ).wait();

        const evt0 = res0.events[res0.events.length - 1];

        expect(evt0.args.outAmts[0]).to.equal(0);
        expectEqualWithError(evt0.args.outAmts[1], expAmtOut0);
        expectEqualWithError(evt0.args.inAmts[0], delta);
        expect(evt0.args.inAmts[1]).to.equal(0);

        const strategyReserves1 = await getStrategyReserves();

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

        const expAmtOut1 = await strategy.testGetAmountIn(
          delta,
          reserves1.sub(expAmtOut0),
          WEIGHTS[1],
          reserves0.add(delta),
          WEIGHTS[0]
        );

        const res1 = await (
          await strategy.testSwapTokens(tokenId, [0, delta])
        ).wait();

        const strategyReserves2 = await getStrategyReserves();

        const evt1 = res1.events[res1.events.length - 1];

        expectEqualWithError(evt1.args.outAmts[0], expAmtOut1);
        expect(evt1.args.outAmts[1]).to.equal(0);
        expect(evt1.args.inAmts[0]).to.equal(0);
        expectEqualWithError(evt1.args.inAmts[1], delta);

        expectEqualWithError(
          strategyReserves2.tokens0,
          strategyReserves1.tokens0.sub(expAmtOut1)
        );
        expectEqualWithError(
          strategyReserves2.tokens1,
          strategyReserves1.tokens1.add(delta)
        );
      });

      it("Swap Exact Tokens for Tokens", async function () {
        const res = await (await strategy.createLoan()).wait();
        const tokenId = res.events[0].args.tokenId;

        const ONE = BigNumber.from(10).pow(18);

        const reserves = await setUpStrategyAndBalancerPool(tokenId);
        const reserves0 = reserves.reserves0;
        const reserves1 = reserves.reserves1;

        const delta = ONE.mul(10);
        const negDelta = ethers.constants.Zero.sub(delta);

        const strategyReserves0 = await getStrategyReserves();

        const expectedAmountOut0 = await strategy.testGetAmountOut(
          delta,
          reserves1,
          WEIGHTS[1],
          reserves0,
          WEIGHTS[0]
        );

        const res0 = await (
          await strategy.testSwapTokens(tokenId, [negDelta, 0])
        ).wait();

        const strategyReserves1 = await getStrategyReserves();

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

        const actualStrategyReserves1 = await getStrategyReserves();

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

        const res1 = await (
          await strategy.testSwapTokens(tokenId, [0, negDelta])
        ).wait();

        const strategyReserves3 = await getStrategyReserves();

        const evt1 = res1.events[res1.events.length - 1];

        const expAmtIn1 = await strategy.testGetAmountOut(
          delta,
          strategyReserves2[0],
          WEIGHTS[0],
          strategyReserves2[1],
          WEIGHTS[1]
        );

        expect(evt1.args.outAmts[0]).to.equal(0);
        expect(evt1.args.outAmts[1]).to.equal(delta);
        expect(evt1.args.inAmts[0]).to.equal(expAmtIn1);
        expect(evt1.args.inAmts[1]).to.equal(0);

        expectEqualWithError(
          strategyReserves3.tokens0,
          strategyReserves2[0].add(expAmtIn1)
        );
        expectEqualWithError(
          strategyReserves3.tokens1,
          strategyReserves2[1].sub(delta)
        );
      });

      // it("Swap Tokens with Fees for Exact Tokens", async function () {
      //   await createStrategy(true, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const fee = BigNumber.from(10).pow(16);

      //   const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      //   const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      //   const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);

      //   const res0 = await (
      //     await strategyFee.testSwapTokens(tokenId, [delta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   expect(evt0.args.outAmts[0]).to.equal(0);
      //   expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);
      //   expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.inAmts[1]).to.equal(0);

      //   const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      //   const deltaFee0Fee = deltaFee0.sub(deltaFee0.mul(fee).div(ONE));
      //   expect(tokenABalance1).to.equal(tokenABalance0.add(deltaFee0Fee));
      //   expect(tokenBBalance1).to.equal(tokenBBalance0.sub(amtOut0));

      //   const _rez = await cfmmFee.getReserves();
      //   const _reserves0 = _rez._reserve0;
      //   const _reserves1 = _rez._reserve1;
      //   await (
      //     await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      //   ).wait();

      //   expect(_reserves0).to.equal(reserves0.sub(deltaFee0));
      //   expect(_reserves1).to.equal(reserves1.add(amtOut0Fee));

      //   const amtOut1 = calcAmtOut(delta, _reserves0, _reserves1, 997, 1000);
      //   const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      //   const deltaFee1 = calcAmtIn(
      //     amtOut1Fee,
      //     _reserves0,
      //     _reserves1,
      //     997,
      //     1000
      //   );

      //   const res1 = await (
      //     await strategyFee.testSwapTokens(tokenId, [0, delta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      //   expect(evt1.args.outAmts[1]).to.equal(0);
      //   expect(evt1.args.inAmts[0]).to.equal(0);
      //   expect(evt1.args.inAmts[1]).to.equal(deltaFee1);

      //   const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      //   const deltaFee1Fee = deltaFee1.sub(deltaFee1.mul(fee).div(ONE));
      //   expect(tokenABalance2).to.equal(tokenABalance1.sub(amtOut1));
      //   expect(tokenBBalance2).to.equal(tokenBBalance1.add(deltaFee1Fee));
      // });

      // it("Swap Exact Tokens with Fees for Tokens", async function () {
      //   await createStrategy(true, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const negDelta = ethers.constants.Zero.sub(delta);
      //   const fee = BigNumber.from(10).pow(16);

      //   const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      //   const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);

      //   const res0 = await (
      //     await strategyFee.testSwapTokens(tokenId, [negDelta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.outAmts[1]).to.equal(0);
      //   expect(evt0.args.inAmts[0]).to.equal(0);
      //   expect(evt0.args.inAmts[1]).to.equal(amtIn0);

      //   const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtIn0Fee = amtIn0.sub(amtIn0.mul(fee).div(ONE));
      //   expect(tokenABalance1).to.equal(tokenABalance0.sub(delta));
      //   expect(tokenBBalance1).to.equal(tokenBBalance0.add(amtIn0Fee));

      //   const _rez = await cfmmFee.getReserves();
      //   const _reserves0 = _rez._reserve0;
      //   const _reserves1 = _rez._reserve1;
      //   await (
      //     await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      //   ).wait();

      //   expect(_reserves0).to.equal(reserves0.add(deltaFee0));
      //   expect(_reserves1).to.equal(reserves1.sub(amtIn0));

      //   const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn1 = calcAmtIn(deltaFee1, _reserves1, _reserves0, 997, 1000);

      //   const res1 = await (
      //     await strategyFee.testSwapTokens(tokenId, [0, negDelta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   expect(evt1.args.outAmts[0]).to.equal(0);
      //   expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
      //   expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      //   expect(evt1.args.inAmts[1]).to.equal(0);

      //   const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtIn1Fee = amtIn1.sub(amtIn1.mul(fee).div(ONE));
      //   expect(tokenABalance2).to.equal(tokenABalance1.add(amtIn1Fee));
      //   expect(tokenBBalance2).to.equal(tokenBBalance1.sub(delta));
      // });

      // it("Swap Tokens A with Fees for Exact Tokens", async function () {
      //   await createStrategy(true, false);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const fee = BigNumber.from(10).pow(16);

      //   const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);

      //   const res0 = await (
      //     await strategyFee.testSwapTokens(tokenId, [delta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   expect(evt0.args.outAmts[0]).to.equal(0);
      //   expect(evt0.args.outAmts[1]).to.equal(amtOut0);
      //   expect(evt0.args.inAmts[0]).to.equal(delta);
      //   expect(evt0.args.inAmts[1]).to.equal(0);

      //   const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      //   const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      //   expect(tokenABalance1).to.equal(tokenABalance0.add(deltaFee0));
      //   expect(tokenBBalance1).to.equal(tokenBBalance0.sub(amtOut0));

      //   const _rez = await cfmmFee.getReserves();
      //   const _reserves0 = _rez._reserve0;
      //   const _reserves1 = _rez._reserve1;
      //   await (
      //     await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      //   ).wait();

      //   expect(_reserves0).to.equal(reserves0.sub(delta));
      //   expect(_reserves1).to.equal(reserves1.add(amtOut0));

      //   const amtOut1 = calcAmtOut(delta, _reserves0, _reserves1, 997, 1000);
      //   const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      //   const deltaFee1 = calcAmtIn(
      //     amtOut1Fee,
      //     _reserves0,
      //     _reserves1,
      //     997,
      //     1000
      //   );

      //   const res1 = await (
      //     await strategyFee.testSwapTokens(tokenId, [0, delta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      //   expect(evt1.args.outAmts[1]).to.equal(0);
      //   expect(evt1.args.inAmts[0]).to.equal(0);
      //   expect(evt1.args.inAmts[1]).to.equal(deltaFee1);

      //   const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      //   expect(tokenABalance2).to.equal(tokenABalance1.sub(amtOut1));
      //   expect(tokenBBalance2).to.equal(tokenBBalance1.add(deltaFee1));
      // });

      // it("Swap Exact Tokens A with Fees for Tokens", async function () {
      //   await createStrategy(true, false);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const negDelta = ethers.constants.Zero.sub(delta);
      //   const fee = BigNumber.from(10).pow(16);

      //   const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      //   const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);

      //   const res0 = await (
      //     await strategyFee.testSwapTokens(tokenId, [negDelta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.outAmts[1]).to.equal(0);
      //   expect(evt0.args.inAmts[0]).to.equal(0);
      //   expect(evt0.args.inAmts[1]).to.equal(amtIn0);

      //   const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      //   expect(tokenABalance1).to.equal(tokenABalance0.sub(delta));
      //   expect(tokenBBalance1).to.equal(tokenBBalance0.add(amtIn0));

      //   const _rez = await cfmmFee.getReserves();
      //   const _reserves0 = _rez._reserve0;
      //   const _reserves1 = _rez._reserve1;
      //   await (
      //     await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      //   ).wait();

      //   expect(_reserves0).to.equal(reserves0.add(deltaFee0));
      //   expect(_reserves1).to.equal(reserves1.sub(amtIn0));

      //   const amtIn1 = calcAmtIn(delta, _reserves1, _reserves0, 997, 1000);

      //   const res1 = await (
      //     await strategyFee.testSwapTokens(tokenId, [0, negDelta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   expect(evt1.args.outAmts[0]).to.equal(0);
      //   expect(evt1.args.outAmts[1]).to.equal(delta);
      //   expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      //   expect(evt1.args.inAmts[1]).to.equal(0);

      //   const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtIn1Fee = amtIn1.sub(amtIn1.mul(fee).div(ONE));
      //   expect(tokenABalance2).to.equal(tokenABalance1.add(amtIn1Fee));
      //   expect(tokenBBalance2).to.equal(tokenBBalance1.sub(delta));
      // });

      // it("Swap Tokens B with Fees for Exact Tokens", async function () {
      //   await createStrategy(false, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const fee = BigNumber.from(10).pow(16);

      //   const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      //   const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      //   const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);

      //   const res0 = await (
      //     await strategyFee.testSwapTokens(tokenId, [delta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   expect(evt0.args.outAmts[0]).to.equal(0);
      //   expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);
      //   expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      //   expect(evt0.args.inAmts[1]).to.equal(0);

      //   const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      //   expect(tokenABalance1).to.equal(tokenABalance0.add(deltaFee0));
      //   expect(tokenBBalance1).to.equal(tokenBBalance0.sub(amtOut0));

      //   const _rez = await cfmmFee.getReserves();
      //   const _reserves0 = _rez._reserve0;
      //   const _reserves1 = _rez._reserve1;
      //   await (
      //     await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      //   ).wait();

      //   expect(_reserves0).to.equal(reserves0.sub(deltaFee0));
      //   expect(_reserves1).to.equal(reserves1.add(amtOut0Fee));

      //   const amtOut1 = calcAmtOut(delta, _reserves0, _reserves1, 997, 1000);

      //   const res1 = await (
      //     await strategyFee.testSwapTokens(tokenId, [0, delta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   expect(evt1.args.outAmts[0]).to.equal(amtOut1);
      //   expect(evt1.args.outAmts[1]).to.equal(0);
      //   expect(evt1.args.inAmts[0]).to.equal(0);
      //   expect(evt1.args.inAmts[1]).to.equal(delta);

      //   const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      //   const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      //   expect(tokenABalance2).to.equal(tokenABalance1.sub(amtOut1));
      //   expect(tokenBBalance2).to.equal(tokenBBalance1.add(deltaFee1));
      // });

      // it("Swap Exact Tokens B with Fees for Tokens", async function () {
      //   await createStrategy(false, true);

      //   const res = await (await strategyFee.createLoan()).wait();
      //   const tokenId = res.events[0].args.tokenId;

      //   const ONE = BigNumber.from(10).pow(18);

      //   const rex = await setUpStrategyAndCFMM(tokenId, true);
      //   const reserves0 = rex.res0;
      //   const reserves1 = rex.res1;

      //   const delta = ONE.mul(10);
      //   const negDelta = ethers.constants.Zero.sub(delta);
      //   const fee = BigNumber.from(10).pow(16);

      //   const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtIn0 = calcAmtIn(delta, reserves0, reserves1, 997, 1000);

      //   const res0 = await (
      //     await strategyFee.testSwapTokens(tokenId, [negDelta, 0])
      //   ).wait();
      //   const evt0 = res0.events[res0.events.length - 1];
      //   expect(evt0.args.outAmts[0]).to.equal(delta);
      //   expect(evt0.args.outAmts[1]).to.equal(0);
      //   expect(evt0.args.inAmts[0]).to.equal(0);
      //   expect(evt0.args.inAmts[1]).to.equal(amtIn0);

      //   const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      //   const amtIn0Fee = amtIn0.sub(amtIn0.mul(fee).div(ONE));
      //   expect(tokenABalance1).to.equal(tokenABalance0.sub(delta));
      //   expect(tokenBBalance1).to.equal(tokenBBalance0.add(amtIn0Fee));

      //   const _rez = await cfmmFee.getReserves();
      //   const _reserves0 = _rez._reserve0;
      //   const _reserves1 = _rez._reserve1;
      //   await (
      //     await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      //   ).wait();

      //   expect(_reserves0).to.equal(reserves0.add(delta));
      //   expect(_reserves1).to.equal(reserves1.sub(amtIn0));

      //   const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      //   const amtIn1 = calcAmtIn(deltaFee1, _reserves1, _reserves0, 997, 1000);

      //   const res1 = await (
      //     await strategyFee.testSwapTokens(tokenId, [0, negDelta])
      //   ).wait();
      //   const evt1 = res1.events[res1.events.length - 1];
      //   expect(evt1.args.outAmts[0]).to.equal(0);
      //   expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
      //   expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      //   expect(evt1.args.inAmts[1]).to.equal(0);

      //   const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      //   const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      //   expect(tokenABalance2).to.equal(tokenABalance1.add(amtIn1));
      //   expect(tokenBBalance2).to.equal(tokenBBalance1.sub(delta));
      // });
    });
  });
});
