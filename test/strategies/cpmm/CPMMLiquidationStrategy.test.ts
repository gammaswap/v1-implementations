import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

describe("CPMMLiquidationStrategy", function () {
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

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestERC20WithFee = await ethers.getContractFactory("TestERC20WithFee");
    [owner, addr1] = await ethers.getSigners();
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
    TestStrategy = await ethers.getContractFactory(
      "TestCPMMLiquidationStrategy"
    );
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
    const maxTotalApy = ONE.mul(10);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    strategy = await TestStrategy.deploy(
      950,
      975,
      maxTotalApy,
      2252571,
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

  async function createStrategy(tok0Fee: any, tok1Fee: any, feePerc: any) {
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

    const fee = feePerc || BigNumber.from(10).pow(15); // 16
    const ONE = BigNumber.from(10).pow(18);

    if (tok0Fee) {
      await (await tokenAFee.setFee(fee)).wait();
    }

    if (tok1Fee) {
      await (await tokenBFee.setFee(fee)).wait();
    }

    const maxTotalApy = ONE.mul(10);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    strategyFee = await TestStrategy.deploy(
      950,
      975,
      maxTotalApy,
      2252571,
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

  async function setUpStrategyAndCFMM2(tokenId: any, hasFee: any) {
    const ONE = BigNumber.from(10).pow(18);

    if (hasFee) {
      strategy = strategyFee;
      tokenA = tokenAFee;
      tokenB = tokenBFee;
      cfmm = cfmmFee;
    }

    const collateral0 = ONE.mul(2);
    const collateral1 = ONE.mul(1);
    const balance0 = ONE.mul(10);
    const balance1 = ONE.mul(20);

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
    await (await cfmm.mint(addr1.address)).wait();

    const rez = await cfmm.getReserves();
    const reserves0 = rez._reserve0;
    const reserves1 = rez._reserve1;

    await (await strategy.setCFMMReserves(reserves0, reserves1, 0)).wait();

    return { res0: reserves0, res1: reserves1 };
  }

  async function setUpStrategyAndCFMM(tokenId: any, hasFee: any) {
    const ONE = BigNumber.from(10).pow(18);

    if (hasFee) {
      strategy = strategyFee;
      tokenA = tokenAFee;
      tokenB = tokenBFee;
      cfmm = cfmmFee;
    }

    const collateral0 = ONE.mul(1);
    const collateral1 = ONE.mul(2);
    const balance0 = ONE.mul(10);
    const balance1 = ONE.mul(20);

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
    await (await cfmm.mint(addr1.address)).wait();

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
      cfmmTotalInvariant: cfmmTotalInvariant,
      cfmmTotalSupply: cfmmTotalSupply,
      cfmmReserve0: rezerves._reserve0,
      cfmmReserve1: rezerves._reserve1,
    };
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

  describe("Liquidate Loans", function () {
    it("Liquidate with collateral", async function () {
      await createStrategy(false, false, null);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const tokensHeld0 = ONE.mul(1);
      const tokensHeld1 = ONE.mul(2);

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
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed)
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).to.equal(tokensHeld1.add(res.tokenBChange));

      // about a month and a half
      await ethers.provider.send("hardhat_mine", ["0x4CFE0"]);

      await (await strategyFee.updateLoanData(tokenId)).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan2.liquidity).gt(res.liquidityBorrowed);
      expect(loan2.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(tokensHeld0.add(res.tokenAChange));
      expect(loan2.tokensHeld[1]).to.equal(tokensHeld1.add(res.tokenBChange));
      expect(await strategyFee.canLiquidate(tokenId)).to.equal(true);

      const token0bal0 = await tokenAFee.balanceOf(owner.address);
      const token1bal0 = await tokenBFee.balanceOf(owner.address);

      await (await strategyFee._liquidate(tokenId, [], [])).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).to.equal(0);
      expect(loan3.liquidity).to.equal(0);
      expect(loan3.lpTokens).to.equal(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).to.equal(0);
      expect(loan3.tokensHeld[1]).to.equal(0);

      const token0bal1 = await tokenAFee.balanceOf(owner.address);
      const token1bal1 = await tokenBFee.balanceOf(owner.address);
      expect(token0bal1).gt(token0bal0);
      expect(token1bal1).gt(token1bal0);
    });

    it("Liquidate with collateral with fees", async function () {
      await createStrategy(true, true, null);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const feePerc = ONE.div(100);
      const feeAmt0 = ONE.mul(1).mul(feePerc).div(ONE);
      const feeAmt1 = ONE.mul(2).mul(feePerc).div(ONE);
      const tokensHeld0 = ONE.mul(1).sub(feeAmt0);
      const tokensHeld1 = ONE.mul(2).sub(feeAmt1);

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
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed)
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).lt(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).lt(tokensHeld1.add(res.tokenBChange));

      // about a month and a half
      await ethers.provider.send("hardhat_mine", ["0x4CFE0"]);

      await (await strategyFee.updateLoanData(tokenId)).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan2.liquidity).gt(res.liquidityBorrowed);
      expect(loan2.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(loan1.tokensHeld[0]);
      expect(loan2.tokensHeld[1]).to.equal(loan1.tokensHeld[1]);
      expect(await strategyFee.canLiquidate(tokenId)).to.equal(true);

      const token0bal0 = await tokenAFee.balanceOf(owner.address);
      const token1bal0 = await tokenBFee.balanceOf(owner.address);

      await expect(strategy._liquidate(tokenId, [], [])).to.be.revertedWith(
        "NotFullLiquidation"
      );

      await (await strategyFee._liquidate(tokenId, [], [12, 12])).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).to.equal(0);
      expect(loan3.liquidity).to.equal(0);
      expect(loan3.lpTokens).to.equal(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).to.equal(0);
      expect(loan3.tokensHeld[1]).to.equal(0);

      const token0bal1 = await tokenAFee.balanceOf(owner.address);
      const token1bal1 = await tokenBFee.balanceOf(owner.address);
      expect(token0bal1).gt(token0bal0);
      expect(token1bal1).gt(token1bal0);
    });

    it("Liquidate with collateral with tokenA fees", async function () {
      await createStrategy(true, false, null);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const feePerc = ONE.div(100);
      const feeAmt0 = ONE.mul(1).mul(feePerc).div(ONE);
      const feeAmt1 = ONE.mul(2).mul(0).div(ONE);
      const tokensHeld0 = ONE.mul(1).sub(feeAmt0);
      const tokensHeld1 = ONE.mul(2).sub(feeAmt1);

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
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed)
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).lt(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).to.equal(tokensHeld1.add(res.tokenBChange));

      // about a month and a half
      await ethers.provider.send("hardhat_mine", ["0x4CFE0"]);

      await (await strategyFee.updateLoanData(tokenId)).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan2.liquidity).gt(res.liquidityBorrowed);
      expect(loan2.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(loan1.tokensHeld[0]);
      expect(loan2.tokensHeld[1]).to.equal(loan1.tokensHeld[1]);
      expect(await strategyFee.canLiquidate(tokenId)).to.equal(true);

      const token0bal0 = await tokenAFee.balanceOf(owner.address);
      const token1bal0 = await tokenBFee.balanceOf(owner.address);

      await expect(strategy._liquidate(tokenId, [], [])).to.be.revertedWith(
        "NotFullLiquidation"
      );

      await (await strategyFee._liquidate(tokenId, [], [12, 0])).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).to.equal(0);
      expect(loan3.liquidity).to.equal(0);
      expect(loan3.lpTokens).to.equal(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).to.equal(0);
      expect(loan3.tokensHeld[1]).to.equal(0);

      const token0bal1 = await tokenAFee.balanceOf(owner.address);
      const token1bal1 = await tokenBFee.balanceOf(owner.address);
      expect(token0bal1).gt(token0bal0);
      expect(token1bal1).gt(token1bal0);
    });

    it("Liquidate with collateral with tokenB fees", async function () {
      await createStrategy(false, true, null);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const feePerc = ONE.div(100);
      const feeAmt0 = ONE.mul(1).mul(0).div(ONE);
      const feeAmt1 = ONE.mul(2).mul(feePerc).div(ONE);
      const tokensHeld0 = ONE.mul(1).sub(feeAmt0);
      const tokensHeld1 = ONE.mul(2).sub(feeAmt1);

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
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed)
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).lt(tokensHeld1.add(res.tokenBChange));

      // about a month and a half
      await ethers.provider.send("hardhat_mine", ["0x4CFE0"]);

      await (await strategyFee.updateLoanData(tokenId)).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan2.liquidity).gt(res.liquidityBorrowed);
      expect(loan2.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(loan1.tokensHeld[0]);
      expect(loan2.tokensHeld[1]).to.equal(loan1.tokensHeld[1]);
      expect(await strategyFee.canLiquidate(tokenId)).to.equal(true);

      const token0bal0 = await tokenAFee.balanceOf(owner.address);
      const token1bal0 = await tokenBFee.balanceOf(owner.address);

      await expect(strategy._liquidate(tokenId, [], [])).to.be.revertedWith(
        "NotFullLiquidation"
      );

      await (await strategyFee._liquidate(tokenId, [], [0, 12])).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).to.equal(0);
      expect(loan3.liquidity).to.equal(0);
      expect(loan3.lpTokens).to.equal(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).to.equal(0);
      expect(loan3.tokensHeld[1]).to.equal(0);

      const token0bal1 = await tokenAFee.balanceOf(owner.address);
      const token1bal1 = await tokenBFee.balanceOf(owner.address);
      expect(token0bal1).gt(token0bal0);
      expect(token1bal1).gt(token1bal0);
    });

    it("Liquidate with collateral with tokenB high fees", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const feePerc = ONE.div(10);
      await createStrategy(false, true, feePerc.div(10));

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const feeAmt0 = ONE.mul(1).mul(0).div(ONE);
      const feeAmt1 = ONE.mul(2).mul(feePerc).div(ONE);
      const tokensHeld0 = ONE.mul(1).sub(feeAmt0);
      const tokensHeld1 = ONE.mul(2).sub(feeAmt1);

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
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed)
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).lt(tokensHeld1.add(res.tokenBChange));

      // about a month and a half
      await ethers.provider.send("hardhat_mine", ["0x4CFE0"]);

      await (await strategyFee.updateLoanData(tokenId)).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan2.liquidity).gt(res.liquidityBorrowed);
      expect(loan2.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(loan1.tokensHeld[0]);
      expect(loan2.tokensHeld[1]).to.equal(loan1.tokensHeld[1]);
      expect(await strategyFee.canLiquidate(tokenId)).to.equal(true);

      await expect(strategy._liquidate(tokenId, [], [])).to.be.revertedWith(
        "NotEnoughCollateral"
      );

      await (await tokenBFee.transfer(strategy.address, ONE.div(20))).wait(); // tree token A transfers at 1% cause a
      const token0bal0 = await tokenAFee.balanceOf(owner.address);
      const token1bal0 = await tokenBFee.balanceOf(owner.address);

      await (await strategyFee._liquidate(tokenId, [], [0, 102])).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).to.equal(0);
      expect(loan3.liquidity).to.equal(0);
      expect(loan3.lpTokens).to.equal(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).to.equal(0);
      expect(loan3.tokensHeld[1]).to.equal(0);

      const token0bal1 = await tokenAFee.balanceOf(owner.address);
      const token1bal1 = await tokenBFee.balanceOf(owner.address);
      expect(token0bal1).gt(token0bal0);
      expect(token1bal1).gt(token1bal0);
    });

    it("Liquidate with collateral, swap", async function () {
      await createStrategy(false, false, null);

      const tokenId = (await (await strategyFee.createLoan()).wait()).events[0]
        .args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const tokensHeld0 = ONE.mul(2);
      const tokensHeld1 = ONE.mul(1);

      await setUpStrategyAndCFMM2(tokenId, true);
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
        await strategyFee._borrowLiquidity(tokenId, lpTokensBorrowed)
      ).wait();
      const loan1 = await strategyFee.getLoan(tokenId);
      expect(loan1.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.liquidity).to.equal(res.liquidityBorrowed);
      expect(loan1.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(tokensHeld0.add(res.tokenAChange));
      expect(loan1.tokensHeld[1]).to.equal(tokensHeld1.add(res.tokenBChange));

      // about a month and a half
      await ethers.provider.send("hardhat_mine", ["0x53688"]);

      await (await strategyFee.updateLoanData(tokenId)).wait();

      const loan2 = await strategyFee.getLoan(tokenId);
      expect(loan2.initLiquidity).to.equal(res.liquidityBorrowed);
      expect(loan2.liquidity).gt(res.liquidityBorrowed);
      expect(loan2.lpTokens).to.equal(lpTokensBorrowed);
      expect(loan2.tokensHeld.length).to.equal(2);
      expect(loan2.tokensHeld[0]).to.equal(loan1.tokensHeld[0]);
      expect(loan2.tokensHeld[1]).to.equal(loan1.tokensHeld[1]);
      expect(await strategyFee.canLiquidate(tokenId)).to.equal(true);

      const token0bal0 = await tokenAFee.balanceOf(owner.address);
      const token1bal0 = await tokenBFee.balanceOf(owner.address);

      const payLiquidity = loan2.liquidity;
      const tokenArepay = payLiquidity
        .mul(res.cfmmReserve0)
        .div(res.cfmmTotalInvariant);
      const tokenBrepay = payLiquidity
        .mul(res.cfmmReserve1)
        .div(res.cfmmTotalInvariant);

      const token0Change = tokenArepay.gt(loan2.tokensHeld[0])
        ? tokenArepay.sub(loan2.tokensHeld[0])
        : 0;
      const token1Change = tokenBrepay.gt(loan2.tokensHeld[1]) // We actually need less than this because there's a writeDown
        ? tokenBrepay.sub(loan2.tokensHeld[1])
        : 0;

      await (
        await strategyFee._liquidate(tokenId, [token0Change, token1Change], [])
      ).wait();

      const loan3 = await strategyFee.getLoan(tokenId);
      expect(loan3.initLiquidity).to.equal(0);
      expect(loan3.liquidity).to.equal(0);
      expect(loan3.lpTokens).to.equal(0);
      expect(loan3.tokensHeld.length).to.equal(2);
      expect(loan3.tokensHeld[0]).to.equal(0);
      expect(loan3.tokensHeld[1]).to.equal(0);

      const token0bal1 = await tokenAFee.balanceOf(owner.address);
      const token1bal1 = await tokenBFee.balanceOf(owner.address);
      expect(token0bal1).gt(token0bal0);
      expect(token1bal1).gt(token1bal0);
    });
  });
});