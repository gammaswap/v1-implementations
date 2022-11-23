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
  const ONE = BigNumber.from(10).pow(18);
  const TWO = BigNumber.from(10).pow(18).mul(2);

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    [owner] = await ethers.getSigners();

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

  const borrowMostOfIt = async (amount: BigNumber) => {
    const res = await (await liquidationStrategy.createLoan()).wait();
    const tokenId = res.events[0].args.tokenId;
    await liquidationStrategy.testOpenLoan(tokenId, amount);
  };

  describe("Test _liquidate", function () {
    it("returns error HasMargin", async function () {
      const startLiquidity = ONE.mul(10);
      const startLpTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      const loanLiquidity = ONE.mul(20000);
      const loanLPTokens = ONE.mul(10);
      const loanTokenAamt = ONE;
      const loanTokenBamt = ONE;
      await (
        await liquidationStrategy.setPoolBalances(
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await liquidationStrategy.testOpenLoan(tokenId, ONE)).wait();
      await (
        await liquidationStrategy.setLoanBalances(
          tokenId,
          loanLiquidity,
          loanLPTokens,
          loanTokenAamt,
          loanTokenBamt
        )
      ).wait();

      await expect(
        liquidationStrategy._liquidate(tokenId, false, [0, 0])
      ).to.be.revertedWith("HasMargin");
    });

    it("does not have enough margin so it liquidates", async function () {
      const startLiquidity = ONE.mul(40);
      const startLpTokens = ONE.mul(20);
      const loanLiquidity = ONE.mul(20000);
      const loanLPTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await liquidationStrategy.setPoolBalances(
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();
      await (await tokenA.mint(liquidationStrategy.address, 50000)).wait();
      await (await tokenB.mint(liquidationStrategy.address, 100000)).wait(); // error if reduced
      await (await liquidationStrategy.setReservesBalance(40000, 40000)).wait();
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await liquidationStrategy.testOpenLoan(tokenId, ONE)).wait();
      const loanTokenAamt = 20000;
      const loanTokenBamt = 20000;
      await (
        await liquidationStrategy.setLoanBalances(
          tokenId,
          loanLiquidity,
          loanLPTokens,
          loanTokenAamt,
          loanTokenBamt
        )
      ).wait();

      await borrowMostOfIt(ONE.mul(30)); // spike up interest, (this doesn't change the result)
      await liquidationStrategy._liquidate(tokenId, false, [0, 0]);

      const res2 = await liquidationStrategy.getLoan(tokenId);
      expect(res2.poolId).to.equal(liquidationStrategy.address);
      expect(res2.tokensHeld[0]).to.equal(0);
      expect(res2.tokensHeld[1]).to.equal(0);
      expect(res2.heldLiquidity).to.equal(0);
      expect(res2.liquidity).to.equal(0);
      expect(res2.lpTokens).to.equal(0);
    });

    it("liquidate with rebalance", async function () {
      const startLiquidity = ONE.mul(40);
      const startLpTokens = ONE.mul(20);
      const loanLiquidity = ONE.mul(20000);
      const loanLPTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await liquidationStrategy.setPoolBalances(
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();
      await (await tokenA.mint(liquidationStrategy.address, 50000)).wait();
      await (await tokenB.mint(liquidationStrategy.address, 100000)).wait(); // error if reduced
      await (await liquidationStrategy.setReservesBalance(40000, 40000)).wait();
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await liquidationStrategy.testOpenLoan(tokenId, ONE)).wait();
      const loanTokenAamt = 20000;
      const loanTokenBamt = 20000;
      await (
        await liquidationStrategy.setLoanBalances(
          tokenId,
          loanLiquidity,
          loanLPTokens,
          loanTokenAamt,
          loanTokenBamt
        )
      ).wait();
      await borrowMostOfIt(ONE.mul(30)); // spike up interest
      await liquidationStrategy._liquidate(tokenId, true, [1000, -1000]);

      const res2 = await liquidationStrategy.getLoan(tokenId);
      expect(res2.poolId).to.equal(liquidationStrategy.address);
      expect(res2.tokensHeld[0]).to.equal(0);
      expect(res2.tokensHeld[1]).to.equal(0);
      expect(res2.heldLiquidity).to.equal(0);
      expect(res2.liquidity).to.equal(0);
      expect(res2.lpTokens).to.equal(0);
    });
  });

  describe("Test _liquidateWithLP", function () {
    it("returns error HasMargin", async function () {
      const startLiquidity = ONE.mul(10);
      const startLpTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      const loanLiquidity = ONE.mul(20000);
      const loanLPTokens = ONE.mul(10);
      const loanTokenAamt = ONE;
      const loanTokenBamt = ONE;
      await (
        await liquidationStrategy.setPoolBalances(
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await liquidationStrategy.testOpenLoan(tokenId, ONE)).wait();
      await (
        await liquidationStrategy.setLoanBalances(
          tokenId,
          loanLiquidity,
          loanLPTokens,
          loanTokenAamt,
          loanTokenBamt
        )
      ).wait();

      await expect(
        liquidationStrategy._liquidateWithLP(tokenId)
      ).to.be.revertedWith("HasMargin");
    });

    it("does not have enough margin so it liquidates", async function () {
      const startLiquidity = ONE.mul(40);
      const startLpTokens = ONE.mul(20);
      const loanLiquidity = ONE.mul(20000);
      const loanLPTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await liquidationStrategy.setPoolBalances(
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();
      await (await tokenA.mint(liquidationStrategy.address, 50000)).wait();
      await (await tokenB.mint(liquidationStrategy.address, 100000)).wait(); // error if reduced
      await (await cfmm.mint(ONE.mul(20), liquidationStrategy.address)).wait();
      await (await liquidationStrategy.setReservesBalance(40000, 40000)).wait();
      const res = await (await liquidationStrategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await liquidationStrategy.testOpenLoan(tokenId, ONE)).wait();
      const loanTokenAamt = 20000;
      const loanTokenBamt = 20000;
      await (
        await liquidationStrategy.setLoanBalances(
          tokenId,
          loanLiquidity,
          loanLPTokens,
          loanTokenAamt,
          loanTokenBamt
        )
      ).wait();
      await borrowMostOfIt(ONE.mul(30)); // spike up interest
      await (await cfmm.mint(ONE, liquidationStrategy.address)).wait(); // this is required to resolve not full 
      await liquidationStrategy._liquidateWithLP(tokenId);

      const res2 = await liquidationStrategy.getLoan(tokenId);
      expect(res2.poolId).to.equal(liquidationStrategy.address);
      expect(res2.tokensHeld[0]).to.equal(0);
      expect(res2.tokensHeld[1]).to.equal(0);
      expect(res2.heldLiquidity).to.equal(0);
      expect(res2.liquidity).to.equal(0);
      expect(res2.lpTokens).to.equal(0);
    });
  });
});
