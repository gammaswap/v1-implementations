import { ethers } from "hardhat";
import { expect } from "chai";

describe("CPMM Short Strategy", function () {
  let TestERC20;
  let GammaPool: any;
  let pool: any;
  let GammaPoolFactory: any;
  let factory: any;
  let TestCPMMShortStrategy: any;
  let TestCFMM: any;
  let testCFMM: any;
  let testCPMMShortStrategy: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
    GammaPool = await ethers.getContractFactory("GammaPool");
    TestCPMMShortStrategy = await ethers.getContractFactory("TestCPMMShortStrategy");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    
    cfmm = await TestERC20.deploy("CFMM LP Token", "LP_CFMM");
    factory = await GammaPoolFactory.deploy(owner.address);

    const COMPUTED_INIT_CODE_HASH = ethers.utils.keccak256(
      GammaPool.bytecode
    );
    const sParams = {
      factory: factory.address,
      initCodeHash: COMPUTED_INIT_CODE_HASH,
      tradingFee1: 1000,
      tradingFee2: 997,
      isSet: false
    }
    const rParams = {
      ONE: 100000,
      YEAR_BLOCK_COUNT: 2252571,
      baseRate: 1000000,
      optimalUtilRate: 800000000,
      slope1: 100000,
      slope2: 100000,
      isSet: false
    }
    const sData =  ethers.utils.defaultAbiCoder.encode(["tuple(address factory, bytes32 initCodeHash, uint16 tradingFee1, uint16 tradingFee2, bool isSet)"],[sParams]);
    const rData =  ethers.utils.defaultAbiCoder.encode(["tuple(uint256 ONE, uint256 YEAR_BLOCK_COUNT, uint256 baseRate, uint256 optimalUtilRate, uint256 slope1, uint256 slope2, bool isSet)"],[rParams]);
    
    testCPMMShortStrategy = await TestCPMMShortStrategy.deploy(sData, rData);
  });

  context("Functions", function () {
    it("Should return optimal amount", async function () {
      await testCPMMShortStrategy.testCheckOptimalAmt(10000, 1000);
    });

    it("Should get reserves", async function () {
      TestCFMM = await ethers.getContractFactory("TestCFMM");
      testCFMM = await TestCFMM.deploy();

      console.log("testCFMM", await ethers.provider.getBalance(owner.address));
      await testCPMMShortStrategy.testDepositToCFMM(testCFMM.address, [1000, 1000], owner.address);
      console.log("testCFMM", await ethers.provider.getBalance(owner.address));
      await testCPMMShortStrategy.testGetReserves(testCFMM.address);
    });
  });
});
