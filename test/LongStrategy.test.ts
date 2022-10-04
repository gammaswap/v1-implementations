import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { Address } from "cluster";

const PROTOCOL_ID = 1;

describe.only("LongStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestStrategyFactory: any;
  // let TestPositionManager: any;
  let TestProtocol: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let factory: any;
  let strategy: any;
  let posManager: any;
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
    TestStrategy = await ethers.getContractFactory("TestLongStrategy");
    // TestPositionManager = await ethers.getContractFactory(
    //   "TestPositionManager"
    // );
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

    await (await factory.createLongStrategy()).wait();
    const strategyAddr = await factory.strategy();

    strategy = await TestStrategy.attach(
      strategyAddr // The deployed contract address
    );
  });

  async function checkBalancesAndLiquidity(
    tokenId: BigNumber,
    tok1Bal: any,
    tok2Bal: any,
    bal1: any,
    bal2: any,
    tokHeld1: any,
    tokHeld2: any,
    heldLiq: any,
    liq: any
  ) {
    const tokenBalances = await strategy.tokenBalances();
    expect(tokenBalances.length).to.equal(2);
    expect(tokenBalances[0]).to.equal(bal1);
    expect(tokenBalances[1]).to.equal(bal2);

    const loanInfo = await strategy.getLoan(tokenId);
    expect(loanInfo.tokensHeld.length).to.equal(2);
    expect(loanInfo.tokensHeld[0]).to.equal(tokHeld1);
    expect(loanInfo.tokensHeld[1]).to.equal(tokHeld2);
    expect(loanInfo.heldLiquidity).to.equal(heldLiq);
    expect(loanInfo.liquidity).to.equal(liq);

    expect(await tokenA.balanceOf(strategy.address)).to.equal(tok1Bal);
    expect(await tokenB.balanceOf(strategy.address)).to.equal(tok2Bal);
  }

  function checkEventData(
    event: any,
    tokenId: BigNumber,
    tokenHeld1: any,
    tokenHeld2: any,
    heldLiquidity: any,
    liquidity: any,
    lpTokens: any,
    rateIndex: any
  ) {
    expect(event.event).to.equal("LoanUpdated");
    expect(event.args.tokenId).to.equal(tokenId);
    expect(event.args.tokensHeld.length).to.equal(2);
    expect(event.args.tokensHeld[0]).to.equal(tokenHeld1);
    expect(event.args.tokensHeld[1]).to.equal(tokenHeld2);
    expect(event.args.heldLiquidity).to.equal(heldLiquidity);
    expect(event.args.liquidity).to.equal(liquidity);
    expect(event.args.lpTokens).to.equal(lpTokens);
    expect(event.args.rateIndex).to.equal(rateIndex);
  }

  async function checkStrategyTokenBalances(bal1: any, bal2: any) {
    const tokenBalances = await strategy.tokenBalances();
    expect(tokenBalances.length).to.equal(2);
    expect(tokenBalances[0]).to.equal(bal1);
    expect(tokenBalances[1]).to.equal(bal2);
    expect(await tokenA.balanceOf(strategy.address)).to.equal(bal1);
    expect(await tokenB.balanceOf(strategy.address)).to.equal(bal2);
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      const tokens = await strategy.tokens();
      expect(tokens.length).to.equal(2);
      expect(tokens[0]).to.equal(tokenA.address);
      expect(tokens[1]).to.equal(tokenB.address);

      const tokenBalances = await strategy.tokenBalances();
      expect(tokenBalances.length).to.equal(2);
      expect(tokenBalances[0]).to.equal(0);
      expect(tokenBalances[1]).to.equal(0);
    });
  });

  describe("Get Loan & Check Margin", function () {
    it("Create and Get Loan", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      const loanInfo = await strategy.getLoan(tokenId);
      expect(loanInfo.id).to.equal(1);
      expect(loanInfo.poolId).to.equal(strategy.address);
      expect(loanInfo.tokensHeld.length).to.equal(2);
      expect(loanInfo.tokensHeld[0]).to.equal(0);
      expect(loanInfo.tokensHeld[1]).to.equal(0);
      expect(loanInfo.heldLiquidity).to.equal(0);
      expect(loanInfo.liquidity).to.equal(0);
      expect(loanInfo.lpTokens).to.equal(0);
      expect(loanInfo.rateIndex).to.equal(BigNumber.from(10).pow(18));
      const latestBlock = await ethers.provider.getBlock("latest");
      expect(loanInfo.blockNum).to.equal(latestBlock.number);

      await expect(strategy.connect(addr1).getLoan(tokenId)).to.be.revertedWith(
        "FORBIDDEN"
      );
    });

    it("Check Margin", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      const ONE = BigNumber.from(10).pow(18);
      await (await strategy.setLiquidity(tokenId, ONE)).wait();
      await (await strategy.setHeldLiquidity(tokenId, ONE)).wait();
      expect(await strategy.checkMargin(tokenId, 1000)).to.equal(true);
      await expect(strategy.checkMargin(tokenId, 999)).to.be.revertedWith(
        "margin"
      );
    });
  });

  describe("Collateral Management", function () {
    it("Increase Collateral", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      await checkBalancesAndLiquidity(tokenId, 0, 0, 0, 0, 0, 0, 0, 0);

      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(100);
      const amtB = ONE.mul(400);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await checkBalancesAndLiquidity(tokenId, amtA, amtB, 0, 0, 0, 0, 0, 0);

      const res1 = await (await strategy._increaseCollateral(tokenId)).wait();
      checkEventData(
        res1.events[0],
        tokenId,
        amtA,
        amtB,
        amtA.mul(2),
        0,
        0,
        ONE
      );

      await checkBalancesAndLiquidity(
        tokenId,
        amtA,
        amtB,
        amtA,
        amtB,
        amtA,
        amtB,
        amtA.mul(2),
        0
      );

      await tokenA.transfer(strategy.address, amtA.mul(3));

      await checkBalancesAndLiquidity(
        tokenId,
        amtB,
        amtB,
        amtA,
        amtB,
        amtA,
        amtB,
        amtA.mul(2),
        0
      );

      const res2 = await (await strategy._increaseCollateral(tokenId)).wait();
      checkEventData(
        res2.events[0],
        tokenId,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        0,
        0,
        ONE
      );

      await checkBalancesAndLiquidity(
        tokenId,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        0
      );

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtA);

      await checkBalancesAndLiquidity(
        tokenId,
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        0
      );

      const res3 = await (await strategy._increaseCollateral(tokenId)).wait();
      checkEventData(
        res3.events[0],
        tokenId,
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(5),
        0,
        0,
        ONE
      );

      await checkBalancesAndLiquidity(
        tokenId,
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(5),
        0
      );
    });

    it("Decrease Collateral", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(200);
      const amtB = ONE.mul(800);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      const ownerBalA = await tokenA.balanceOf(owner.address);
      const ownerBalB = await tokenB.balanceOf(owner.address);

      const res1 = await (await strategy._increaseCollateral(tokenId)).wait();
      checkEventData(
        res1.events[0],
        tokenId,
        amtA,
        amtB,
        amtA.mul(2),
        0,
        0,
        ONE
      );

      await checkStrategyTokenBalances(amtA, amtB);

      const res2 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2), amtB.div(2)],
          owner.address
        )
      ).wait();
      checkEventData(
        res2.events[res2.events.length - 1],
        tokenId,
        amtA.div(2),
        amtB.div(2),
        amtA,
        0,
        0,
        ONE
      );

      expect(await tokenA.balanceOf(owner.address)).to.equal(
        ownerBalA.add(amtA.div(2))
      );
      expect(await tokenB.balanceOf(owner.address)).to.equal(
        ownerBalB.add(amtB.div(2))
      );

      await checkStrategyTokenBalances(amtA.div(2), amtB.div(2));

      await expect(
        strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2).add(1), amtB.div(2)],
          owner.address
        )
      ).to.be.revertedWith("> amt");

      await expect(
        strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2), amtB.div(2).add(1)],
          owner.address
        )
      ).to.be.revertedWith("> amt");

      const addr1BalA = await tokenA.balanceOf(addr1.address);
      const addr1BalB = await tokenB.balanceOf(addr1.address);

      const res3 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(4), amtB.div(4)],
          addr1.address
        )
      ).wait();

      checkEventData(
        res3.events[res3.events.length - 1],
        tokenId,
        amtA.div(4),
        amtB.div(4),
        amtA.div(2),
        0,
        0,
        ONE
      );

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(4))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(4))
      );

      await checkStrategyTokenBalances(amtA.div(4), amtB.div(4));

      await (await strategy.setLiquidity(tokenId, ONE.mul(80))).wait();

      await expect(
        strategy._decreaseCollateral(tokenId, [1, 0], owner.address)
      ).to.be.revertedWith("margin");

      await expect(
        strategy._decreaseCollateral(tokenId, [0, 1], owner.address)
      ).to.be.revertedWith("margin");

      const res4 = await (
        await strategy._decreaseCollateral(tokenId, [0, 0], addr1.address)
      ).wait();

      checkEventData(
        res4.events[res4.events.length - 1],
        tokenId,
        amtA.div(4),
        amtB.div(4),
        amtA.div(2),
        ONE.mul(80),
        0,
        ONE
      );

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(4))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(4))
      );

      await checkStrategyTokenBalances(amtA.div(4), amtB.div(4));

      await (await strategy.setLiquidity(tokenId, ONE.mul(40))).wait();

      const res5 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(8), amtB.div(8)],
          addr1.address
        )
      ).wait();

      checkEventData(
        res5.events[res5.events.length - 1],
        tokenId,
        amtA.div(8),
        amtB.div(8),
        amtA.div(4),
        ONE.mul(40),
        0,
        ONE
      );

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(4)).add(amtA.div(8))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(4)).add(amtB.div(8))
      );

      await checkStrategyTokenBalances(amtA.div(8), amtB.div(8));

      await (await strategy.setLiquidity(tokenId, 0)).wait();

      const res6 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(8), amtB.div(8)],
          addr1.address
        )
      ).wait();

      checkEventData(
        res6.events[res6.events.length - 1],
        tokenId,
        0,
        0,
        0,
        0,
        0,
        ONE
      );

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(2))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(2))
      );

      await checkStrategyTokenBalances(0, 0);
    });
  });
});
