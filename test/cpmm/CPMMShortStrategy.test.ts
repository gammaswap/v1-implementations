import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

const PROTOCOL_ID = 1;

describe.only("CPMMBaseStrategy", function () {
  let TestERC20: any;
  let TestStrategy: any;
  let TestStrategyFactory: any;
  let TestProtocol: any;
  let UniswapV2Factory: any;
  let UniswapV2Pair: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let factory: any;
  let uniFactory: any;
  let strategy: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let protocol: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestStrategyFactory = await ethers.getContractFactory(
      "TestStrategyFactory"
    );
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
    TestStrategy = await ethers.getContractFactory("TestCPMMShortStrategy");
    TestProtocol = await ethers.getContractFactory("TestProtocol");

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

    await (await factory.createCPMMShortStrategy()).wait();
    const strategyAddr = await factory.strategy();

    strategy = await TestStrategy.attach(
      strategyAddr // The deployed contract address
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

  async function sendToCFMM(amtA: BigNumber, amtB: BigNumber) {
    await tokenA.transfer(cfmm.address, amtA);
    await tokenB.transfer(cfmm.address, amtB);
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      expect(await strategy.factory()).to.equal(factory.address);
      expect(await strategy.initCodeHash()).to.equal(
        await strategy.INIT_CODE_HASH()
      );
      expect(await strategy.tradingFee1()).to.equal(1);
      expect(await strategy.tradingFee2()).to.equal(2);
    });
  });

  describe("Calc Deposit Amounts Functions", function () {
    it("Check Optimal Amt", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amountOptimal = ONE.mul(100);
      const amountMin = amountOptimal.add(1);

      await expect(
        strategy.testCheckOptimalAmt(amountOptimal, amountMin)
      ).to.be.revertedWith("< minAmt");

      expect(
        await strategy.testCheckOptimalAmt(amountOptimal, amountMin.sub(1))
      ).to.equal(3);
      expect(
        await strategy.testCheckOptimalAmt(amountOptimal.add(1), amountMin)
      ).to.equal(3);
      expect(
        await strategy.testCheckOptimalAmt(amountOptimal.add(2), amountMin)
      ).to.equal(3);
    });

    it("Get Reserves", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(20);
      const amtB = ONE.mul(500);
      await sendToCFMM(amtA, amtB);

      const res0 = await strategy.testGetReserves(cfmm.address);
      expect(res0.length).to.equal(2);
      expect(res0[0]).to.equal(0);
      expect(res0[1]).to.equal(0);

      await (await cfmm.mint(owner.address)).wait();

      const res1 = await strategy.testGetReserves(cfmm.address);
      expect(res1.length).to.equal(2);
      expect(res1[0]).to.equal(amtA);
      expect(res1[1]).to.equal(amtB);

      await sendToCFMM(amtA, amtB);

      await (await cfmm.mint(owner.address)).wait();

      const res2 = await strategy.testGetReserves(cfmm.address);
      expect(res2.length).to.equal(2);
      expect(res2[0]).to.equal(amtA.mul(2));
      expect(res2[1]).to.equal(amtB.mul(2));

      await (await cfmm.transfer(cfmm.address, ONE.mul(50))).wait();
      await (await cfmm.burn(owner.address)).wait();

      const res3 = await strategy.testGetReserves(cfmm.address);
      expect(res3.length).to.equal(2);
      expect(res3[0]).to.equal(amtA.mul(2).sub(amtA.div(2)));
      expect(res3[1]).to.equal(amtB.mul(2).sub(amtB.div(2)));
    });

    it("Error Calc Deposit Amounts", async function () {
      // amounts 0  // require(amountsDesired[0] > 0 && amountsDesired[1] > 0, "0 amount");
      // reserves are 0
      /*
        payee = store.cfmm;
        if (reserve0 == 0 && reserve1 == 0) {
            return(amountsDesired, payee);
        }

        require(reserve0 > 0 && reserve1 > 0, "0 reserve");
      * */
      // require(amountOptimal >= amountMin, "< minAmt");
    });
  });
});
