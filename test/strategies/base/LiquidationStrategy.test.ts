import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("LiquidationStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestLiquidationStrategy: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let liquidationStrategy: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let protocol: any;
  const ONE = BigNumber.from(10).pow(18);
  const TWO = BigNumber.from(10).pow(18).mul(2);
  const FOUR = BigNumber.from(10).pow(18).mul(4);

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    [owner, addr1, addr2] = await ethers.getSigners();

    TestLiquidationStrategy = await ethers.getContractFactory(
      "TestLiquidationStrategy"
    );
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    TestCFMM = await ethers.getContractFactory("TestCFMM");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    // because Uniswap's CFMM reorders tokenA and tokenB in increasing order
    const token0addr = await cfmm.token0();
    const token1addr = await cfmm.token1();
    tokenA = await TestERC20.attach(token0addr);
    tokenB = await TestERC20.attach(token1addr);

    liquidationStrategy = await TestLiquidationStrategy.deploy();
    await (
      await liquidationStrategy.initialize(cfmm.address, PROTOCOL_ID, [
        tokenA.address,
        tokenB.address,
      ])
    ).wait();
  });

  const depositToStrategy = async (startLpTokens: BigNumber) => {
    const ONE = BigNumber.from(10).pow(18);
    const startLiquidity = ONE.mul(800);
    const lastCFMMInvariant = startLiquidity.mul(2);
    const lastCFMMTotalSupply = startLpTokens.mul(2);
    await (
      await liquidationStrategy.setLPTokenBalance(
        startLiquidity,
        startLpTokens,
        lastCFMMInvariant,
        lastCFMMTotalSupply
      )
    ).wait();

    await (await cfmm.mint(startLpTokens, liquidationStrategy.address)).wait();
  };

  const borrowMostOfIt = async (amount: BigNumber) => {
    const res = await (await liquidationStrategy.createLoan()).wait();
    const tokenId = res.events[0].args.tokenId;
    await liquidationStrategy.testOpenLoan(tokenId, amount);
  };

  describe("Test _liquidate", function () {
    it("returns error HasMargin", async function () {
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await expect(
        liquidationStrategy._liquidate(tokenId, false, [0, 0])
      ).to.be.revertedWith("HasMargin");
    });

    it("does not have enough margin so it liquidates", async function () {
      await depositToStrategy(FOUR);
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await liquidationStrategy.testOpenLoan(tokenId, ONE)).wait();
      await borrowMostOfIt(TWO); // spike up interest
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const loanLiquidity = ONE.mul(20);
      const loanLPTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await liquidationStrategy.setLPTokenLoanBalance(
          tokenId,
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();
      await (
        await liquidationStrategy.setHeldAmounts(tokenId, [19999, 19999])
      ).wait();
      await liquidationStrategy._liquidate(tokenId, false, [0, 0]);

      const res1b = await liquidationStrategy.getLoan(tokenId);
      expect(res1b.poolId).to.equal(liquidationStrategy.address);
      expect(res1b.tokensHeld[0]).to.equal(0);
      expect(res1b.tokensHeld[1]).to.equal(0);
      expect(res1b.heldLiquidity).to.equal(0);
      expect(res1b.liquidity).to.equal(0);
      expect(res1b.lpTokens).to.equal(0);
    });
  });

  describe("Test _liquidateWithLP", function () {
    it("returns error HasMargin", async function () {
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await expect(
        liquidationStrategy._liquidateWithLP(tokenId)
      ).to.be.revertedWith("HasMargin");
    });

    it("does not have enough margin so it liquidates", async function () {
      await depositToStrategy(ONE.mul(500));
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await liquidationStrategy.testOpenLoan(tokenId, ONE)).wait();
      await borrowMostOfIt(TWO); // spike up interest
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(100);
      const loanLiquidity = ONE.mul(20000);
      const loanLPTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await liquidationStrategy.setLPTokenLoanBalance(
          tokenId,
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();
      await (await cfmm.mint(ONE.mul(200), owner.address)).wait();
      await liquidationStrategy._liquidateWithLP(tokenId);

      const res1b = await liquidationStrategy.getLoan(tokenId);
      expect(res1b.poolId).to.equal(liquidationStrategy.address);
      expect(res1b.tokensHeld[0]).to.equal(0);
      expect(res1b.tokensHeld[1]).to.equal(0);
      expect(res1b.heldLiquidity).to.equal(0);
      expect(res1b.liquidity).to.equal(0);
      expect(res1b.lpTokens).to.equal(0);
    });
  });
});
