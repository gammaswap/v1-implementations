import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("LiquidationStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestProtocol: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let strategy: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let protocol: any;
  const ONE = BigNumber.from(10).pow(18);
  const TWO = BigNumber.from(10).pow(18).mul(2);
  const FOUR = BigNumber.from(10).pow(18).mul(4);

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    TestStrategy = await ethers.getContractFactory("TestLiquidationStrategy");
    TestProtocol = await ethers.getContractFactory("TestProtocol");
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

    protocol = await TestProtocol.deploy(
      PROTOCOL_ID,
      addr1.address,
      addr2.address
    );

    strategy = await TestStrategy.deploy();

    await (
      await strategy.initialize(cfmm.address, PROTOCOL_ID, protocol.address, [
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
      await strategy.setLPTokenBalance(
        startLiquidity,
        startLpTokens,
        lastCFMMInvariant,
        lastCFMMTotalSupply
      )
    ).wait();

    await (await cfmm.mint(startLpTokens, strategy.address)).wait();
  };

  const borrowMostOfIt = async (amount: BigNumber) => {
    const res = await (await strategy.createLoan()).wait();
    // console.log("res", res)
    const tokenId = res.events[0].args.tokenId;
    await strategy.testOpenLoan(tokenId, amount);
  };

  describe("Test _liquidate", function () {
    it("returns error HasMargin", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await expect(
        strategy._liquidate(tokenId, false, [0, 0])
      ).to.be.revertedWith("HasMargin");
    });

    it("does not have enough margin so it liquidates", async function () {
      await depositToStrategy(FOUR);
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      await (await strategy.testOpenLoan(tokenId, ONE)).wait();
      await borrowMostOfIt(TWO); // spike up interest
      await (
        await strategy.setTokenBalances(tokenId, 400, 400, 400, 400)
      ).wait();
      await strategy._liquidate(tokenId, false, [0, 0]);
    });
  });

  describe("Test _liquidateWithLP", function () {
    // it("returns error HasMargin", async function () {
    //   const res = await (await strategy.createLoan()).wait();
    //   const tokenId = res.events[0].args.tokenId;
    //   await expect(
    //     strategy._liquidate(tokenId, false, [0, 0])
    //   ).to.be.revertedWith("HasMargin");
    // });

    // it("does not have enough enough margin", async function () {
    //   await depositToStrategy(FOUR);
    //   const res = await (await strategy.createLoan()).wait();
    //   const tokenId = res.events[0].args.tokenId;
    //   await (await strategy.testOpenLoan(tokenId, ONE)).wait();
    //   await borrowMostOfIt(TWO); // spike up interest
    //   await strategy._liquidate(tokenId, false, [0, 0]);
    // });
  });
});
