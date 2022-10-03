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

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      /*const ONE = BigNumber.from(10).pow(18);
      const assets = ONE.mul(100);
      const _totalAssets = await strategy.getTotalAssets();
      await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool
      expect(await strategy.getTotalAssets()).to.equal(
        _totalAssets.add(assets)
      );

      const shares = ONE.mul(100);
      const _totalSupply = await strategy.totalSupply();
      await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool
      expect(await strategy.totalSupply()).to.equal(_totalSupply.add(shares));/**/
    });
  });
});
