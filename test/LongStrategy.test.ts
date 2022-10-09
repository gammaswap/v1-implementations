import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe.only("LongStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestStrategyFactory: any;
  let TestProtocol: any;
  let TestDeployer: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let factory: any;
  let strategy: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let protocol: any;
  let deployer: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategyFactory = await ethers.getContractFactory(
      "TestStrategyFactory"
    );
    TestDeployer = await ethers.getContractFactory("TestLongStrategyDeployer");
    TestStrategy = await ethers.getContractFactory("TestLongStrategy");
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

    deployer = await TestDeployer.deploy(factory.address);

    await (await factory.createStrategy(deployer.address)).wait();
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

  function checkEventData2(
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
    expect(event.args.rateIndex).to.gt(rateIndex);
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
      ).to.be.revertedWith("> bal");

      const resp = await (await strategy.createLoan()).wait();
      const tokenId2 = resp.events[0].args.tokenId;

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await (await strategy._increaseCollateral(tokenId2)).wait();

      await expect(
        strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2).add(1), amtB.div(2)],
          owner.address
        )
      ).to.be.revertedWith("> held");

      await expect(
        strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2), amtB.div(2).add(1)],
          owner.address
        )
      ).to.be.revertedWith("> held");

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

      await (
        await strategy._decreaseCollateral(
          tokenId2,
          [amtA, amtB],
          owner.address
        )
      ).wait();

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

      await checkStrategyTokenBalances(0, 0); /**/
    });

    it("Decrease Collateral, UpdateIndex", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(200);
      const amtB = ONE.mul(800);

      await (await strategy.setBorrowRate(ONE)).wait();

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

      checkEventData2(
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
    });
  });

  describe("Borrow and Repay Loans", function () {
    it("Check Set LP Token Balances", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;
      const ONE = BigNumber.from(10).pow(18);
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanLiquidity).to.equal(0);
      expect(res2.loanLpTokens).to.equal(0);
      expect(res2.borrowedInvariant).to.equal(0);
      expect(res2.lpInvariant).to.equal(0);
      expect(res2.totalInvariant).to.equal(0);
      expect(res2.lpTokenBorrowed).to.equal(0);
      expect(res2.lpTokenBalance).to.equal(0);
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res2.lpTokenTotal).to.equal(0);

      const startLpTokens = ONE.mul(400);
      const startLiquidity = ONE.mul(800);
      await (
        await strategy.setLPTokenBalance(startLpTokens, startLiquidity)
      ).wait();

      const res3 = await strategy.getLoanChangeData(tokenId);
      expect(res3.loanLiquidity).to.equal(0);
      expect(res3.loanLpTokens).to.equal(0);
      expect(res3.borrowedInvariant).to.equal(0);
      expect(res3.lpInvariant).to.equal(startLiquidity);
      expect(res3.totalInvariant).to.equal(startLiquidity);
      expect(res3.lpTokenBorrowed).to.equal(0);
      expect(res3.lpTokenBalance).to.equal(startLpTokens);
      expect(res3.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res3.lpTokenTotal).to.equal(startLpTokens);
    });

    it("Open Loan", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const startLpTokens = ONE.mul(400);
      const startLiquidity = ONE.mul(800);
      await (
        await strategy.setLPTokenBalance(startLpTokens, startLiquidity)
      ).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanLiquidity).to.equal(liquidity);
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity);
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity);
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens);
      expect(res2.lpTokenTotal).to.equal(startLpTokens);

      const lpTokens1 = ONE.mul(300);
      const liquidity1 = ONE.mul(600);
      await (await strategy.testOpenLoan(tokenId, lpTokens1)).wait();
      const res3 = await strategy.getLoanChangeData(tokenId);
      expect(res3.loanLiquidity).to.equal(liquidity.add(liquidity1));
      expect(res3.loanLpTokens).to.equal(lpTokens.add(lpTokens1));
      expect(res3.borrowedInvariant).to.equal(liquidity.add(liquidity1));
      expect(res3.lpInvariant).to.equal(
        startLiquidity.sub(liquidity).sub(liquidity1)
      );
      expect(res3.totalInvariant).to.equal(startLiquidity);
      expect(res3.lpTokenBorrowed).to.equal(lpTokens.add(lpTokens1));
      expect(res3.lpTokenBalance).to.equal(
        startLpTokens.sub(lpTokens).sub(lpTokens1)
      );
      expect(res3.lpTokenBorrowedPlusInterest).to.equal(
        lpTokens.add(lpTokens1)
      );
      expect(res3.lpTokenTotal).to.equal(startLpTokens);
    });

    it("Pay Loan", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const startLpTokens = ONE.mul(400);
      const startLiquidity = ONE.mul(800);
      await (
        await strategy.setLPTokenBalance(startLpTokens, startLiquidity)
      ).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanLiquidity).to.equal(liquidity);
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity);
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity);
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens);
      expect(res2.lpTokenTotal).to.equal(startLpTokens);

      const lpInterestYield = ONE.div(10);
      const lpIntMult = ONE.add(lpInterestYield);
      const lpTokenInterest = lpTokens.mul(lpInterestYield).div(ONE);
      await (
        await strategy.chargeLPTokenInterest(tokenId, lpTokenInterest)
      ).wait();

      const res3 = await strategy.getLoanChangeData(tokenId);
      expect(res3.loanLiquidity).to.equal(liquidity.mul(lpIntMult).div(ONE));
      expect(res3.loanLpTokens).to.equal(lpTokens);
      expect(res3.borrowedInvariant).to.equal(
        liquidity.mul(lpIntMult).div(ONE)
      );
      const liquidityInterest = liquidity.mul(lpInterestYield).div(ONE);
      expect(res3.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res3.totalInvariant).to.equal(
        startLiquidity.add(liquidityInterest)
      );
      expect(res3.lpTokenBorrowed).to.equal(lpTokens);
      expect(res3.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res3.lpTokenBorrowedPlusInterest).to.equal(
        lpTokens.add(lpTokenInterest)
      );
      expect(res3.lpTokenTotal).to.equal(startLpTokens.add(lpTokenInterest));
    });
  });
});
