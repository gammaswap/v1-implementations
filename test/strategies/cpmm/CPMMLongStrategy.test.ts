import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

describe("CPMMLongStrategy", function () {
  let TestERC20: any;
  let TestERC20WithFee: any;
  let TestStrategy: any;
  let TestGammaPoolFactory: any;
  let UniswapV2Factory: any;
  let UniswapV2Pair: any;
  let tokenA: any;
  let tokenB: any;
  let tokenAFee: any;
  let tokenBFee: any;
  let cfmm: any;
  let cfmmFee: any;
  let uniFactory: any;
  let gsFactory: any;
  let strategy: any;
  let strategyFee: any;
  let owner: any;
  let addr1: any;
  let addr2: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestERC20WithFee = await ethers.getContractFactory("TestERC20WithFee");
    [owner, addr1, addr2] = await ethers.getSigners();
    UniswapV2Factory = new ethers.ContractFactory(
      UniswapV2FactoryJSON.abi,
      UniswapV2FactoryJSON.bytecode,
      owner
    );
    UniswapV2Pair = new ethers.ContractFactory(
      UniswapV2PairJSON.abi,
      UniswapV2PairJSON.bytecode,
      owner
    );
    TestGammaPoolFactory = await ethers.getContractFactory(
      "TestGammaPoolFactory"
    );
    TestStrategy = await ethers.getContractFactory("TestCPMMLongStrategy");
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    uniFactory = await UniswapV2Factory.deploy(owner.address);

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

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    strategy = await TestStrategy.deploy(
      0,
      997,
      1000,
      baseRate,
      factor,
      maxApy
    );

    // address _feeToSetter, uint16 _fee
    gsFactory = await TestGammaPoolFactory.deploy(owner.address, 10000);

    await (
      await strategy.initialize(
        gsFactory.address,
        cfmm.address,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();
  });

  async function createStrategy(tok0Fee: any, tok1Fee: any) {
    const _tokenAFee = await TestERC20WithFee.deploy(
      "Test Token A Fee",
      "TOKAF",
      0
    );
    const _tokenBFee = await TestERC20WithFee.deploy(
      "Test Token B Fee",
      "TOKBF",
      0
    );

    cfmmFee = await createPair(_tokenAFee, _tokenBFee);

    // because Uniswap's CFMM reorders tokenA and tokenB in increasing order
    const token0addr = await cfmmFee.token0();
    const token1addr = await cfmmFee.token1();

    tokenAFee = await TestERC20WithFee.attach(
      token0addr // The deployed contract address
    );

    tokenBFee = await TestERC20WithFee.attach(
      token1addr // The deployed contract address
    );

    const fee = BigNumber.from(10).pow(16);

    if (tok0Fee) {
      await (await tokenAFee.setFee(fee)).wait();
    }

    if (tok1Fee) {
      await (await tokenBFee.setFee(fee)).wait();
    }

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    strategyFee = await TestStrategy.deploy(
      0,
      997,
      1000,
      baseRate,
      factor,
      maxApy
    );

    await (
      await strategyFee.initialize(
        gsFactory.address,
        cfmmFee.address,
        [tokenAFee.address, tokenBFee.address],
        [18, 18]
      )
    ).wait();
  }

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

  function calcAmtIn(
    amountOut: BigNumber,
    reserveOut: BigNumber,
    reserveIn: BigNumber,
    tradingFee1: any,
    tradingFee2: any
  ): BigNumber {
    const amountOutWithFee = amountOut.mul(tradingFee1);
    const denominator = reserveOut.mul(tradingFee2).add(amountOutWithFee);
    return amountOutWithFee.mul(reserveIn).div(denominator);
  }

  function calcAmtOut(
    amountIn: BigNumber,
    reserveOut: BigNumber,
    reserveIn: BigNumber,
    tradingFee1: any,
    tradingFee2: any
  ): BigNumber {
    const denominator = reserveIn.sub(amountIn).mul(tradingFee1);
    const num = reserveOut.mul(amountIn).mul(tradingFee2).div(denominator);
    return num.add(1);
  }

  async function setUpStrategyAndCFMM(tokenId: any, hasFee: any) {
    const ONE = BigNumber.from(10).pow(18);

    if (hasFee) {
      strategy = strategyFee;
      tokenA = tokenAFee;
      tokenB = tokenBFee;
      cfmm = cfmmFee;
    }

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

    await (await tokenA.transfer(cfmm.address, ONE.mul(5000))).wait();
    await (await tokenB.transfer(cfmm.address, ONE.mul(10000))).wait();
    await (await cfmm.mint(addr2.address)).wait();

    const rez = await cfmm.getReserves();
    const reserves0 = rez._reserve0;
    const reserves1 = rez._reserve1;

    await (await strategy.setCFMMReserves(reserves0, reserves1, 0)).wait();

    return { res0: reserves0, res1: reserves1 };
  }

  async function setUpLoanableLiquidity(tokenId: any, hasFee: any) {
    const ONE = BigNumber.from(10).pow(18);

    if (hasFee) {
      strategy = strategyFee;
      tokenA = tokenAFee;
      tokenB = tokenBFee;
      cfmm = cfmmFee;
    }

    await (await tokenA.transfer(cfmm.address, ONE.mul(5))).wait();
    await (await tokenB.transfer(cfmm.address, ONE.mul(10))).wait();
    await (await cfmm.mint(strategy.address)).wait();

    await (await strategy.depositLPTokens(tokenId)).wait();
  }

  const sqrt = (y: BigNumber): BigNumber => {
    let z = BigNumber.from(0);
    if (y.gt(3)) {
      z = y;
      let x = y.div(2).add(1);
      while (x.lt(z)) {
        z = x;
        x = y.div(x).add(x).div(2);
      }
    } else if (!y.isZero()) {
      z = BigNumber.from(1);
    }
    return z;
  };

  async function getBalanceChanges(
    lpTokensBorrowed: BigNumber,
    feeA: any,
    feeB: any
  ) {
    const rezerves = await cfmmFee.getReserves();
    const cfmmTotalInvariant = sqrt(rezerves._reserve0.mul(rezerves._reserve1));
    const cfmmTotalSupply = await cfmmFee.totalSupply();
    const liquidityBorrowed = lpTokensBorrowed
      .mul(cfmmTotalInvariant)
      .div(cfmmTotalSupply);
    const tokenAChange = lpTokensBorrowed
      .mul(rezerves._reserve0)
      .div(cfmmTotalSupply);
    const tokenBChange = lpTokensBorrowed
      .mul(rezerves._reserve1)
      .div(cfmmTotalSupply);

    const ONE = BigNumber.from(10).pow(18);
    const feeAmt0 = tokenAChange.mul(feeA).div(ONE);
    const feeAmt1 = tokenBChange.mul(feeB).div(ONE);

    return {
      liquidityBorrowed: liquidityBorrowed,
      tokenAChange: tokenAChange.sub(feeAmt0),
      tokenBChange: tokenBChange.sub(feeAmt1),
    };
  }

  function getTokensHeld(amt0: any, amt1: any, fee0: any, fee1: any) {
    const ONE = BigNumber.from(10).pow(18);
    const feeAmt0 = amt0.mul(fee0).div(ONE);
    const feeAmt1 = amt1.mul(fee1).div(ONE);
    return { tokensHeld0: amt0.sub(feeAmt0), tokensHeld1: amt1.sub(feeAmt1) };
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      expect(await strategy.origFee()).to.equal(0);
      expect(await strategy.tradingFee1()).to.equal(997);
      expect(await strategy.tradingFee2()).to.equal(1000);
      const ONE = BigNumber.from(10).pow(18);
      const baseRate = ONE.div(100);
      const factor = ONE.mul(4).div(100);
      const maxApy = ONE.mul(75).div(100);
      expect(await strategy.baseRate()).to.equal(baseRate);
      expect(await strategy.factor()).to.equal(factor);
      expect(await strategy.maxApy()).to.equal(maxApy);
      expect(await strategy.BLOCKS_PER_YEAR()).to.equal(2252571);
      expect(await strategy.MAX_TOTAL_APY()).to.equal(ONE.mul(10));
    });
  });

  describe("Repay Functions", function () {
    it("Calc Tokens to Repay", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const reserves0 = ONE.mul(500);
      const reserves1 = ONE.mul(1000);
      const lastCFMMInvariant = ONE.mul(1000);
      const liquidity = ONE.mul(100);
      await (
        await strategy.setCFMMReserves(reserves0, reserves1, lastCFMMInvariant)
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

    it("Error Before Repay", async function () {
      const ONE = BigNumber.from(10).pow(18);

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await expect(
        strategy.testBeforeRepay(tokenId, [1, 1])
      ).to.be.revertedWith("NotEnoughBalance");

      expect(await tokenA.balanceOf(cfmm.address)).to.equal(0);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(0);

      await (await strategy.setTokenBalances(tokenId, 10, 10, 100, 10)).wait();

      await expect(
        strategy.testBeforeRepay(tokenId, [11, 1])
      ).to.be.revertedWith("NotEnoughCollateral");

      expect(await tokenA.balanceOf(cfmm.address)).to.equal(0);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(0);

      const amtA = ONE.mul(100);
      const amtB = ONE.mul(200);

      await (await tokenA.transfer(strategy.address, amtA)).wait();
      await (await tokenB.transfer(strategy.address, amtB)).wait();

      await expect(
        strategy.testBeforeRepay(tokenId, [1, 11])
      ).to.be.revertedWith("NotEnoughBalance");

      expect(await tokenA.balanceOf(cfmm.address)).to.equal(0);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(0);

      await (await strategy.setTokenBalances(tokenId, 10, 10, 100, 11)).wait();

      await expect(
        strategy.testBeforeRepay(tokenId, [1, 11])
      ).to.be.revertedWith("NotEnoughCollateral");

      expect(await tokenA.balanceOf(cfmm.address)).to.equal(0);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(0);
    });

    it("Before Repay", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await (await tokenA.transfer(strategy.address, 100)).wait();
      await (await tokenB.transfer(strategy.address, 200)).wait();

      expect(await tokenA.balanceOf(strategy.address)).to.equal(100);
      expect(await tokenB.balanceOf(strategy.address)).to.equal(200);
      expect(await tokenA.balanceOf(cfmm.address)).to.equal(0);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(0);

      await (
        await strategy.setTokenBalances(tokenId, 100, 200, 100, 200)
      ).wait();

      await (await strategy.testBeforeRepay(tokenId, [100, 200])).wait();

      expect(await tokenA.balanceOf(cfmm.address)).to.equal(100);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(200);
      expect(await tokenA.balanceOf(strategy.address)).to.equal(0);
      expect(await tokenB.balanceOf(strategy.address)).to.equal(0);

      await (await tokenA.transfer(strategy.address, 300)).wait();
      await (await tokenB.transfer(strategy.address, 140)).wait();

      expect(await tokenA.balanceOf(strategy.address)).to.equal(300);
      expect(await tokenB.balanceOf(strategy.address)).to.equal(140);
      expect(await tokenA.balanceOf(cfmm.address)).to.equal(100);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(200);

      await (await strategy.setTokenBalances(tokenId, 150, 70, 150, 70)).wait();

      await (await strategy.testBeforeRepay(tokenId, [150, 70])).wait();

      expect(await tokenA.balanceOf(strategy.address)).to.equal(150);
      expect(await tokenB.balanceOf(strategy.address)).to.equal(70);
      expect(await tokenA.balanceOf(cfmm.address)).to.equal(250);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(270);

      await (await strategy.testBeforeRepay(tokenId, [150, 70])).wait();

      expect(await tokenA.balanceOf(strategy.address)).to.equal(0);
      expect(await tokenB.balanceOf(strategy.address)).to.equal(0);
      expect(await tokenA.balanceOf(cfmm.address)).to.equal(400);
      expect(await tokenB.balanceOf(cfmm.address)).to.equal(340);
    });
  });

  describe("Repay Loans", function () {
    it("Repay Tokens without Fees", async function () {
      await createStrategy(false, false);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const tokensHeld0 = ONE.mul(100);
      const tokensHeld1 = ONE.mul(200);

      await setUpStrategyAndCFMM(tokenId, true);
      await setUpLoanableLiquidity(tokenId, true);

      const loan0 = await strategyFee.getLoan(tokenId);
      expect(loan0.initLiquidity).to.equal(0);
      expect(loan0.liquidity).to.equal(0);
      expect(loan0.lpTokens).to.equal(0);
      expect(loan0.tokensHeld.length).to.equal(2);
      expect(loan0.tokensHeld[0]).to.equal(tokensHeld0);
      expect(loan0.tokensHeld[1]).to.equal(tokensHeld1);

      const lpTokensBorrowed = ONE;
      const res = await getBalanceChanges(lpTokensBorrowed, 0, 0);
      await (
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed, [])
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).to.equal(tokensHeld1.add(res.tokenBChange));

      const payLiquidity = res.liquidityBorrowed;

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).gt(0);
      expect(loan2.liquidity).gt(0);
      expect(loan2.lpTokens).gt(0);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(tokensHeld0);
      expect(loan2.tokensHeld[1]).to.equal(tokensHeld1);

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).to.equal(0);
      expect(loan3.liquidity).to.equal(0);
      expect(loan3.lpTokens).to.equal(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).lt(tokensHeld0);
      expect(loan3.tokensHeld[1]).lt(tokensHeld1);
    });

    it("Repay Tokens with Fees", async function () {
      await createStrategy(true, true);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const fee = ONE.div(10);
      const _held = getTokensHeld(ONE.mul(100), ONE.mul(200), fee, fee);
      const tokensHeld0 = _held.tokensHeld0;
      const tokensHeld1 = _held.tokensHeld1;

      await setUpStrategyAndCFMM(tokenId, true);
      await setUpLoanableLiquidity(tokenId, true);

      const loan0 = await strategyFee.getLoan(tokenId);
      expect(loan0.initLiquidity).to.equal(0);
      expect(loan0.liquidity).to.equal(0);
      expect(loan0.lpTokens).to.equal(0);
      expect(loan0.tokensHeld.length).to.equal(2);
      expect(loan0.tokensHeld[0]).to.equal(tokensHeld0);
      expect(loan0.tokensHeld[1]).to.equal(tokensHeld1);

      const lpTokensBorrowed = ONE;
      const res = await getBalanceChanges(lpTokensBorrowed, 0, 0);
      await (
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed, [])
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).lt(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).lt(tokensHeld1.add(res.tokenBChange));

      const payLiquidity = res.liquidityBorrowed;

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).gt(0);
      expect(loan2.liquidity).gt(0);
      expect(loan2.lpTokens).gt(0);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).lt(tokensHeld0);
      expect(loan2.tokensHeld[1]).lt(tokensHeld1);

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).gt(0);
      expect(loan3.liquidity).gt(0);
      expect(loan3.lpTokens).gt(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).lt(tokensHeld0);
      expect(loan3.tokensHeld[1]).lt(tokensHeld1);

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [1000, 1000],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan4 = await strategyFee.getLoan(tokenId);
      expect(loan4.initLiquidity).to.equal(0);
      expect(loan4.liquidity).to.equal(0);
      expect(loan4.lpTokens).to.equal(0);
      expect(loan4.tokensHeld.length).to.equal(2);
      expect(loan4.tokensHeld[0]).lt(tokensHeld0);
      expect(loan4.tokensHeld[1]).lt(tokensHeld1);
    });

    it("Repay Tokens with only TokenA Fees", async function () {
      await createStrategy(true, false);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const fee = ONE.div(10);
      const _held = getTokensHeld(ONE.mul(100), ONE.mul(200), fee, 0);
      const tokensHeld0 = _held.tokensHeld0;
      const tokensHeld1 = _held.tokensHeld1;

      await setUpStrategyAndCFMM(tokenId, true);
      await setUpLoanableLiquidity(tokenId, true);

      const loan0 = await strategyFee.getLoan(tokenId);
      expect(loan0.initLiquidity).to.equal(0);
      expect(loan0.liquidity).to.equal(0);
      expect(loan0.lpTokens).to.equal(0);
      expect(loan0.tokensHeld.length).to.equal(2);
      expect(loan0.tokensHeld[0]).to.equal(tokensHeld0);
      expect(loan0.tokensHeld[1]).to.equal(tokensHeld1);

      const lpTokensBorrowed = ONE;
      const res = await getBalanceChanges(lpTokensBorrowed, 0, 0);
      await (
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed, [])
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).lt(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).to.equal(tokensHeld1.add(res.tokenBChange));

      const payLiquidity = res.liquidityBorrowed;

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).gt(0);
      expect(loan2.liquidity).gt(0);
      expect(loan2.lpTokens).gt(0);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).lt(tokensHeld0);
      expect(loan2.tokensHeld[1]).to.equal(tokensHeld1);

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).gt(0);
      expect(loan3.liquidity).gt(0);
      expect(loan3.lpTokens).gt(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).lt(tokensHeld0);
      expect(loan3.tokensHeld[1]).lt(tokensHeld1);

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [1000, 0],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan4 = await strategyFee.getLoan(tokenId);
      expect(loan4.initLiquidity).to.equal(0);
      expect(loan4.liquidity).to.equal(0);
      expect(loan4.lpTokens).to.equal(0);
      expect(loan4.tokensHeld.length).to.equal(2);
      expect(loan4.tokensHeld[0]).lt(tokensHeld0);
      expect(loan4.tokensHeld[1]).lt(tokensHeld1);
    });

    it("Repay Tokens with only TokenB Fees", async function () {
      await createStrategy(false, true);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const fee = ONE.div(10);
      const _held = getTokensHeld(ONE.mul(100), ONE.mul(200), 0, fee);
      const tokensHeld0 = _held.tokensHeld0;
      const tokensHeld1 = _held.tokensHeld1;

      await setUpStrategyAndCFMM(tokenId, true);
      await setUpLoanableLiquidity(tokenId, true);

      const loan0 = await strategyFee.getLoan(tokenId);
      expect(loan0.initLiquidity).to.equal(0);
      expect(loan0.liquidity).to.equal(0);
      expect(loan0.lpTokens).to.equal(0);
      expect(loan0.tokensHeld.length).to.equal(2);
      expect(loan0.tokensHeld[0]).to.equal(tokensHeld0);
      expect(loan0.tokensHeld[1]).to.equal(tokensHeld1);

      const lpTokensBorrowed = ONE;
      const res = await getBalanceChanges(lpTokensBorrowed, 0, 0);
      await (
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed, [])
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).lt(tokensHeld1.add(res.tokenBChange));

      const payLiquidity = res.liquidityBorrowed;

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).gt(0);
      expect(loan2.liquidity).gt(0);
      expect(loan2.lpTokens).gt(0);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(tokensHeld0);
      expect(loan2.tokensHeld[1]).lt(tokensHeld1);

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).gt(0);
      expect(loan3.liquidity).gt(0);
      expect(loan3.lpTokens).gt(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).lt(tokensHeld0);
      expect(loan3.tokensHeld[1]).lt(tokensHeld1);

      await (
        await strategyFee._repayLiquidity(
          tokenId,
          payLiquidity,
          [0, 1000],
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const loan4 = await strategyFee.getLoan(tokenId);
      expect(loan4.initLiquidity).to.equal(0);
      expect(loan4.liquidity).to.equal(0);
      expect(loan4.lpTokens).to.equal(0);
      expect(loan4.tokensHeld.length).to.equal(2);
      expect(loan4.tokensHeld[0]).lt(tokensHeld0);
      expect(loan4.tokensHeld[1]).lt(tokensHeld1);
    });
  });

  describe("Calc Amt In/Out", function () {
    it("Error Calc Amt In", async function () {
      await expect(strategy.testCalcAmtIn(0, 0, 0)).to.be.revertedWith(
        "ZeroReserves"
      );
      await expect(strategy.testCalcAmtIn(1000000000, 0, 0)).to.be.revertedWith(
        "ZeroReserves"
      );
      await expect(
        strategy.testCalcAmtIn(1000000000, 1000000000, 0)
      ).to.be.revertedWith("ZeroReserves");
      await expect(
        strategy.testCalcAmtIn(1000000000, 0, 1000000000)
      ).to.be.revertedWith("ZeroReserves");
    });

    it("Error Calc Amt Out", async function () {
      await expect(strategy.testCalcAmtOut(0, 0, 0)).to.be.revertedWith(
        "ZeroReserves"
      );
      await expect(
        strategy.testCalcAmtOut(1000000000, 0, 0)
      ).to.be.revertedWith("ZeroReserves");
      await expect(
        strategy.testCalcAmtOut(1000000000, 1000000000, 0)
      ).to.be.revertedWith("ZeroReserves");
      await expect(
        strategy.testCalcAmtOut(1000000000, 0, 1000000000)
      ).to.be.revertedWith("ZeroReserves");
    });

    it("Calc Amt In", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amountOut = ONE.mul(100);
      const reserveOut = ONE.mul(500);
      const reserveIn = ONE.mul(1000);
      const amtIn1a = await strategy.testCalcAmtIn(
        amountOut,
        reserveOut,
        reserveIn
      );
      const amtIn1b = calcAmtIn(amountOut, reserveOut, reserveIn, 997, 1000);
      expect(amtIn1a).to.equal(amtIn1b);

      const amtIn2a = await strategy.testCalcAmtIn(
        amountOut.mul(2),
        reserveOut,
        reserveIn.mul(3)
      );
      const amtIn2b = calcAmtIn(
        amountOut.mul(2),
        reserveOut,
        reserveIn.mul(3),
        997,
        1000
      );
      expect(amtIn2a).to.equal(amtIn2b);

      const amtIn3a = await strategy.testCalcAmtIn(
        amountOut.mul(2),
        reserveOut.mul(7),
        reserveIn.mul(3)
      );
      const amtIn3b = calcAmtIn(
        amountOut.mul(2),
        reserveOut.mul(7),
        reserveIn.mul(3),
        997,
        1000
      );
      expect(amtIn3a).to.equal(amtIn3b);

      const amtIn4a = await strategy.testCalcAmtIn(
        amountOut.mul(2),
        reserveOut.mul(7),
        reserveIn.mul(3)
      );
      const amtIn4b = calcAmtIn(
        amountOut.mul(2),
        reserveOut.mul(7),
        reserveIn.mul(3),
        998,
        1000
      );
      expect(amtIn4a).lt(amtIn4b);

      const amtIn5a = await strategy.testCalcAmtIn(
        amountOut.mul(2),
        reserveOut.mul(7),
        reserveIn.mul(3)
      );
      const amtIn5b = calcAmtIn(
        amountOut.mul(2),
        reserveOut.mul(7),
        reserveIn.mul(3),
        996,
        1000
      );
      expect(amtIn5a).gt(amtIn5b);
    });

    it("Calc Amt Out", async function () {
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

    it("Error Calc Actual Out Amount", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amt = ONE.mul(100);
      await expect(
        strategy.testCalcActualOutAmount(
          tokenA.address,
          addr1.address,
          amt,
          amt.sub(1),
          amt
        )
      ).to.be.revertedWith("NotEnoughBalance");
      await expect(
        strategy.testCalcActualOutAmount(
          tokenA.address,
          addr1.address,
          amt,
          amt,
          amt.sub(1)
        )
      ).to.be.revertedWith("NotEnoughCollateral");
    });

    it("Calc Actual Out Amount", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amt = ONE.mul(100);

      await (await tokenA.transfer(strategy.address, amt)).wait();
      await (await tokenA.transfer(addr1.address, amt)).wait();

      const balance0 = await tokenA.balanceOf(addr1.address);
      const res = await (
        await strategy.testCalcActualOutAmount(
          tokenA.address,
          addr1.address,
          amt,
          amt,
          amt
        )
      ).wait();
      const evt = res.events[res.events.length - 1];
      expect(evt.args.outAmount).to.equal(amt);

      const balance1 = await tokenA.balanceOf(addr1.address);
      expect(evt.args.outAmount).to.equal(balance1.sub(balance0));
    });
  });

  describe("Calc Tokens to Swap", function () {
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

    it("Calc Exact Tokens to Buy", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, false);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);

      // buy exactly delta
      const res0 = await (
        await strategy.testBeforeSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(delta);
      expect(evt0.args.inAmts[1]).to.equal(0);
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(amtOut0);

      // buy exactly delta
      const res1 = await (
        await strategy.testBeforeSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const amtOut1 = calcAmtOut(delta, reserves0, reserves1, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(delta);
      expect(evt1.args.outAmts[0]).to.equal(amtOut1);
      expect(evt1.args.outAmts[1]).to.equal(0);
    });

    it("Calc Exact Tokens to Sell", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, false);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);

      // sell exactly delta
      const res0 = await (
        await strategy.testBeforeSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const amtIn0 = calcAmtIn(delta, reserves0, reserves1, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(amtIn0);
      expect(evt0.args.outAmts[0]).to.equal(delta);
      expect(evt0.args.outAmts[1]).to.equal(0);

      // sell exactly delta
      const res1 = await (
        await strategy.testBeforeSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const amtIn1 = calcAmtIn(delta, reserves1, reserves0, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);
      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(delta);
    });

    it("Calc Exact Tokens with Fees to Buy", async function () {
      await createStrategy(true, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const fee = BigNumber.from(10).pow(16);

      // buy exactly delta
      const res0 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.inAmts[1]).to.equal(0);
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);

      // buy exactly delta
      const res1 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const amtOut1 = calcAmtOut(delta, reserves0, reserves1, 997, 1000);
      const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      const deltaFee1 = calcAmtIn(amtOut1Fee, reserves0, reserves1, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(deltaFee1);
      expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      expect(evt1.args.outAmts[1]).to.equal(0);
    });

    it("Calc Exact Tokens with Fees to Sell", async function () {
      await createStrategy(true, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);
      const fee = BigNumber.from(10).pow(16);

      // sell exactly delta
      const res0 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(amtIn0);
      expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.outAmts[1]).to.equal(0);

      // sell exactly delta
      const res1 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn1 = calcAmtIn(deltaFee0, reserves1, reserves0, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);
      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
    });

    it("Calc Exact Tokens A with Fees to Buy", async function () {
      await createStrategy(true, false);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const fee = BigNumber.from(10).pow(16);

      // buy exactly delta
      const res0 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(delta);
      expect(evt0.args.inAmts[1]).to.equal(0);
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(amtOut0);

      // buy exactly delta
      const res1 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const amtOut1 = calcAmtOut(delta, reserves0, reserves1, 997, 1000);
      const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      const deltaFee1 = calcAmtIn(amtOut1Fee, reserves0, reserves1, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(deltaFee1);
      expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      expect(evt1.args.outAmts[1]).to.equal(0);
    });

    it("Calc Exact Tokens A with Fees to Sell", async function () {
      await createStrategy(true, false);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);
      const fee = BigNumber.from(10).pow(16);

      // sell exactly delta
      const res0 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(amtIn0);
      expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.outAmts[1]).to.equal(0);

      // sell exactly delta
      const res1 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const amtIn1 = calcAmtIn(delta, reserves1, reserves0, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);
      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(delta);
    });

    it("Calc Exact Tokens B with Fees to Buy", async function () {
      await createStrategy(false, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const fee = BigNumber.from(10).pow(16);

      // buy exactly delta
      const res0 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.inAmts[1]).to.equal(0);
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);

      // buy exactly delta
      const res1 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const amtOut1 = calcAmtOut(delta, reserves0, reserves1, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(delta);
      expect(evt1.args.outAmts[0]).to.equal(amtOut1);
      expect(evt1.args.outAmts[1]).to.equal(0);
    });

    it("Calc Exact Tokens B with Fees to Sell", async function () {
      await createStrategy(false, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);
      const fee = BigNumber.from(10).pow(16);

      // sell exactly delta
      const res0 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      const amtIn0 = calcAmtIn(delta, reserves0, reserves1, 997, 1000);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(amtIn0);
      expect(evt0.args.outAmts[0]).to.equal(delta);
      expect(evt0.args.outAmts[1]).to.equal(0);

      // sell exactly delta
      const res1 = await (
        await strategyFee.testBeforeSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn1 = calcAmtIn(deltaFee1, reserves1, reserves0, 997, 1000);
      expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);
      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
    });
  });

  describe("Swap Tokens", function () {
    it("Swap Tokens for Exact Tokens", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, false);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);

      const tokenABalance0 = await tokenA.balanceOf(strategy.address);
      const tokenBBalance0 = await tokenB.balanceOf(strategy.address);

      const expAmtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      const res0 = await (
        await strategy.testSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(expAmtOut0);
      expect(evt0.args.inAmts[0]).to.equal(delta);
      expect(evt0.args.inAmts[1]).to.equal(0);

      const tokenABalance1 = await tokenA.balanceOf(strategy.address);
      const tokenBBalance1 = await tokenB.balanceOf(strategy.address);

      expect(tokenABalance1).to.equal(tokenABalance0.add(delta));
      expect(tokenBBalance1).to.equal(tokenBBalance0.sub(expAmtOut0));

      await (
        await strategy.setCFMMReserves(
          reserves0.sub(delta),
          reserves1.add(expAmtOut0),
          0
        )
      ).wait();

      const expAmtOut1 = calcAmtOut(
        delta,
        reserves0.sub(delta),
        reserves1.add(expAmtOut0),
        997,
        1000
      );
      const res1 = await (
        await strategy.testSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      expect(evt1.args.outAmts[0]).to.equal(expAmtOut1);
      expect(evt1.args.outAmts[1]).to.equal(0);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(delta);

      const tokenABalance2 = await tokenA.balanceOf(strategy.address);
      const tokenBBalance2 = await tokenB.balanceOf(strategy.address);

      expect(tokenABalance2).to.equal(tokenABalance1.sub(expAmtOut1));
      expect(tokenBBalance2).to.equal(tokenBBalance1.add(delta));
    });

    it("Swap Exact Tokens for Tokens", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, false);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);

      const tokenABalance0 = await tokenA.balanceOf(strategy.address);
      const tokenBBalance0 = await tokenB.balanceOf(strategy.address);

      const expAmtIn0 = calcAmtIn(delta, reserves0, reserves1, 997, 1000);
      const res0 = await (
        await strategy.testSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(delta);
      expect(evt0.args.outAmts[1]).to.equal(0);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(expAmtIn0);

      const tokenABalance1 = await tokenA.balanceOf(strategy.address);
      const tokenBBalance1 = await tokenB.balanceOf(strategy.address);

      expect(tokenABalance1).to.equal(tokenABalance0.sub(delta));
      expect(tokenBBalance1).to.equal(tokenBBalance0.add(expAmtIn0));

      await (
        await strategy.setCFMMReserves(
          reserves0.add(delta),
          reserves1.sub(expAmtIn0),
          0
        )
      ).wait();

      const rez = await cfmm.getReserves();
      expect(rez._reserve0).to.equal(reserves0.add(delta));
      expect(rez._reserve1).to.equal(reserves1.sub(expAmtIn0));

      const res1 = await (
        await strategy.testSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      const expAmtIn1 = calcAmtIn(
        delta,
        reserves1.sub(expAmtIn0),
        reserves0.add(delta),
        997,
        1000
      );

      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(delta);
      expect(evt1.args.inAmts[0]).to.equal(expAmtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);

      const tokenABalance2 = await tokenA.balanceOf(strategy.address);
      const tokenBBalance2 = await tokenB.balanceOf(strategy.address);

      expect(tokenABalance2).to.equal(tokenABalance1.add(expAmtIn1));
      expect(tokenBBalance2).to.equal(tokenBBalance1.sub(delta));
    });

    it("Swap Tokens with Fees for Exact Tokens", async function () {
      await createStrategy(true, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const fee = BigNumber.from(10).pow(16);

      const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);

      const res0 = await (
        await strategyFee.testSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);
      expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.inAmts[1]).to.equal(0);

      const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      const deltaFee0Fee = deltaFee0.sub(deltaFee0.mul(fee).div(ONE));
      expect(tokenABalance1).to.equal(tokenABalance0.add(deltaFee0Fee));
      expect(tokenBBalance1).to.equal(tokenBBalance0.sub(amtOut0));

      const _rez = await cfmmFee.getReserves();
      const _reserves0 = _rez._reserve0;
      const _reserves1 = _rez._reserve1;
      await (
        await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      ).wait();

      expect(_reserves0).to.equal(reserves0.sub(deltaFee0));
      expect(_reserves1).to.equal(reserves1.add(amtOut0Fee));

      const amtOut1 = calcAmtOut(delta, _reserves0, _reserves1, 997, 1000);
      const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      const deltaFee1 = calcAmtIn(
        amtOut1Fee,
        _reserves0,
        _reserves1,
        997,
        1000
      );

      const res1 = await (
        await strategyFee.testSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      expect(evt1.args.outAmts[1]).to.equal(0);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(deltaFee1);

      const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      const deltaFee1Fee = deltaFee1.sub(deltaFee1.mul(fee).div(ONE));
      expect(tokenABalance2).to.equal(tokenABalance1.sub(amtOut1));
      expect(tokenBBalance2).to.equal(tokenBBalance1.add(deltaFee1Fee));
    });

    it("Swap Exact Tokens with Fees for Tokens", async function () {
      await createStrategy(true, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);
      const fee = BigNumber.from(10).pow(16);

      const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);

      const res0 = await (
        await strategyFee.testSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.outAmts[1]).to.equal(0);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(amtIn0);

      const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      const amtIn0Fee = amtIn0.sub(amtIn0.mul(fee).div(ONE));
      expect(tokenABalance1).to.equal(tokenABalance0.sub(delta));
      expect(tokenBBalance1).to.equal(tokenBBalance0.add(amtIn0Fee));

      const _rez = await cfmmFee.getReserves();
      const _reserves0 = _rez._reserve0;
      const _reserves1 = _rez._reserve1;
      await (
        await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      ).wait();

      expect(_reserves0).to.equal(reserves0.add(deltaFee0));
      expect(_reserves1).to.equal(reserves1.sub(amtIn0));

      const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn1 = calcAmtIn(deltaFee1, _reserves1, _reserves0, 997, 1000);

      const res1 = await (
        await strategyFee.testSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
      expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);

      const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      const amtIn1Fee = amtIn1.sub(amtIn1.mul(fee).div(ONE));
      expect(tokenABalance2).to.equal(tokenABalance1.add(amtIn1Fee));
      expect(tokenBBalance2).to.equal(tokenBBalance1.sub(delta));
    });

    it("Swap Tokens A with Fees for Exact Tokens", async function () {
      await createStrategy(true, false);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const fee = BigNumber.from(10).pow(16);

      const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);

      const res0 = await (
        await strategyFee.testSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(amtOut0);
      expect(evt0.args.inAmts[0]).to.equal(delta);
      expect(evt0.args.inAmts[1]).to.equal(0);

      const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      expect(tokenABalance1).to.equal(tokenABalance0.add(deltaFee0));
      expect(tokenBBalance1).to.equal(tokenBBalance0.sub(amtOut0));

      const _rez = await cfmmFee.getReserves();
      const _reserves0 = _rez._reserve0;
      const _reserves1 = _rez._reserve1;
      await (
        await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      ).wait();

      expect(_reserves0).to.equal(reserves0.sub(delta));
      expect(_reserves1).to.equal(reserves1.add(amtOut0));

      const amtOut1 = calcAmtOut(delta, _reserves0, _reserves1, 997, 1000);
      const amtOut1Fee = amtOut1.sub(amtOut1.mul(fee).div(ONE));
      const deltaFee1 = calcAmtIn(
        amtOut1Fee,
        _reserves0,
        _reserves1,
        997,
        1000
      );

      const res1 = await (
        await strategyFee.testSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      expect(evt1.args.outAmts[0]).to.equal(amtOut1Fee);
      expect(evt1.args.outAmts[1]).to.equal(0);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(deltaFee1);

      const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      expect(tokenABalance2).to.equal(tokenABalance1.sub(amtOut1));
      expect(tokenBBalance2).to.equal(tokenBBalance1.add(deltaFee1));
    });

    it("Swap Exact Tokens A with Fees for Tokens", async function () {
      await createStrategy(true, false);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);
      const fee = BigNumber.from(10).pow(16);

      const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      const deltaFee0 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn0 = calcAmtIn(deltaFee0, reserves0, reserves1, 997, 1000);

      const res0 = await (
        await strategyFee.testSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.outAmts[1]).to.equal(0);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(amtIn0);

      const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      expect(tokenABalance1).to.equal(tokenABalance0.sub(delta));
      expect(tokenBBalance1).to.equal(tokenBBalance0.add(amtIn0));

      const _rez = await cfmmFee.getReserves();
      const _reserves0 = _rez._reserve0;
      const _reserves1 = _rez._reserve1;
      await (
        await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      ).wait();

      expect(_reserves0).to.equal(reserves0.add(deltaFee0));
      expect(_reserves1).to.equal(reserves1.sub(amtIn0));

      const amtIn1 = calcAmtIn(delta, _reserves1, _reserves0, 997, 1000);

      const res1 = await (
        await strategyFee.testSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(delta);
      expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);

      const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      const amtIn1Fee = amtIn1.sub(amtIn1.mul(fee).div(ONE));
      expect(tokenABalance2).to.equal(tokenABalance1.add(amtIn1Fee));
      expect(tokenBBalance2).to.equal(tokenBBalance1.sub(delta));
    });

    it("Swap Tokens B with Fees for Exact Tokens", async function () {
      await createStrategy(false, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const fee = BigNumber.from(10).pow(16);

      const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      const amtOut0 = calcAmtOut(delta, reserves1, reserves0, 997, 1000);
      const amtOut0Fee = amtOut0.sub(amtOut0.mul(fee).div(ONE));
      const deltaFee0 = calcAmtIn(amtOut0Fee, reserves1, reserves0, 997, 1000);

      const res0 = await (
        await strategyFee.testSwapTokens(tokenId, [delta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(0);
      expect(evt0.args.outAmts[1]).to.equal(amtOut0Fee);
      expect(evt0.args.inAmts[0]).to.equal(deltaFee0);
      expect(evt0.args.inAmts[1]).to.equal(0);

      const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      expect(tokenABalance1).to.equal(tokenABalance0.add(deltaFee0));
      expect(tokenBBalance1).to.equal(tokenBBalance0.sub(amtOut0));

      const _rez = await cfmmFee.getReserves();
      const _reserves0 = _rez._reserve0;
      const _reserves1 = _rez._reserve1;
      await (
        await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      ).wait();

      expect(_reserves0).to.equal(reserves0.sub(deltaFee0));
      expect(_reserves1).to.equal(reserves1.add(amtOut0Fee));

      const amtOut1 = calcAmtOut(delta, _reserves0, _reserves1, 997, 1000);

      const res1 = await (
        await strategyFee.testSwapTokens(tokenId, [0, delta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      expect(evt1.args.outAmts[0]).to.equal(amtOut1);
      expect(evt1.args.outAmts[1]).to.equal(0);
      expect(evt1.args.inAmts[0]).to.equal(0);
      expect(evt1.args.inAmts[1]).to.equal(delta);

      const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      expect(tokenABalance2).to.equal(tokenABalance1.sub(amtOut1));
      expect(tokenBBalance2).to.equal(tokenBBalance1.add(deltaFee1));
    });

    it("Swap Exact Tokens B with Fees for Tokens", async function () {
      await createStrategy(false, true);

      const res = await (await strategyFee.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);

      const rex = await setUpStrategyAndCFMM(tokenId, true);
      const reserves0 = rex.res0;
      const reserves1 = rex.res1;

      const delta = ONE.mul(10);
      const negDelta = ethers.constants.Zero.sub(delta);
      const fee = BigNumber.from(10).pow(16);

      const tokenABalance0 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance0 = await tokenBFee.balanceOf(strategyFee.address);

      const amtIn0 = calcAmtIn(delta, reserves0, reserves1, 997, 1000);

      const res0 = await (
        await strategyFee.testSwapTokens(tokenId, [negDelta, 0])
      ).wait();
      const evt0 = res0.events[res0.events.length - 1];
      expect(evt0.args.outAmts[0]).to.equal(delta);
      expect(evt0.args.outAmts[1]).to.equal(0);
      expect(evt0.args.inAmts[0]).to.equal(0);
      expect(evt0.args.inAmts[1]).to.equal(amtIn0);

      const tokenABalance1 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance1 = await tokenBFee.balanceOf(strategyFee.address);

      const amtIn0Fee = amtIn0.sub(amtIn0.mul(fee).div(ONE));
      expect(tokenABalance1).to.equal(tokenABalance0.sub(delta));
      expect(tokenBBalance1).to.equal(tokenBBalance0.add(amtIn0Fee));

      const _rez = await cfmmFee.getReserves();
      const _reserves0 = _rez._reserve0;
      const _reserves1 = _rez._reserve1;
      await (
        await strategyFee.setCFMMReserves(_reserves0, _reserves1, 0)
      ).wait();

      expect(_reserves0).to.equal(reserves0.add(delta));
      expect(_reserves1).to.equal(reserves1.sub(amtIn0));

      const deltaFee1 = delta.sub(delta.mul(fee).div(ONE));
      const amtIn1 = calcAmtIn(deltaFee1, _reserves1, _reserves0, 997, 1000);

      const res1 = await (
        await strategyFee.testSwapTokens(tokenId, [0, negDelta])
      ).wait();
      const evt1 = res1.events[res1.events.length - 1];
      expect(evt1.args.outAmts[0]).to.equal(0);
      expect(evt1.args.outAmts[1]).to.equal(deltaFee1);
      expect(evt1.args.inAmts[0]).to.equal(amtIn1);
      expect(evt1.args.inAmts[1]).to.equal(0);

      const tokenABalance2 = await tokenAFee.balanceOf(strategyFee.address);
      const tokenBBalance2 = await tokenBFee.balanceOf(strategyFee.address);

      expect(tokenABalance2).to.equal(tokenABalance1.add(amtIn1));
      expect(tokenBBalance2).to.equal(tokenBBalance1.sub(delta));
    });
  });
});
