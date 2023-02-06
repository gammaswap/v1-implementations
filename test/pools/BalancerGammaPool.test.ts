import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");

// Protocol ID for Balancer
const PROTOCOL_ID = 2;

describe("BalancerGammaPool", function () {
  let TestERC20: any;
  let BalancerGammaPool: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let tokenD: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let pool: any;
  let longStrategyAddr: any;
  let shortStrategyAddr: any;
  let liquidationStrategyAddr: any;
  let cfmm: any;
  let weighted3Pool: any;

  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let vault: any;
  let factory: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    BalancerGammaPool = await ethers.getContractFactory("BalancerGammaPool");

    [owner] = await ethers.getSigners();

    // Get contract factory for WeightedPool: '@balancer-labs/v2-pool-weighted/WeightedPoolFactory'
    WeightedPoolFactory = new ethers.ContractFactory(
      _WeightedPoolFactoryAbi,
      _WeightedPoolFactoryBytecode.creationCode,
      owner
    );

    // Get contract factory for Vault: '@balancer-labs/v2-vault/contracts/Vault'
    BalancerVault = new ethers.ContractFactory(
      _Vault.abi,
      _Vault.bytecode,
      owner
    );

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    const HOUR = 60 * 60;
    const DAY = HOUR * 24;
    const MONTH = DAY * 30;

    // Deploy the Vault contract
    vault = await BalancerVault.deploy(
      owner.address,
      tokenA.address,
      MONTH,
      MONTH
    );

    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");
    tokenD = await TestERC20.deploy("Test Token D", "TOKD");

    // Deploy the WeightedPoolFactory contract
    factory = await WeightedPoolFactory.deploy(
      vault.address // The vault address is given to the factory so it can create pools with the correct vault
    );

    // Create a WeightedPool using the WeightedPoolFactory
    cfmm = await createPair(tokenA, tokenB);

    // Create a 3 token WeightedPool using the WeightedPoolFactory
    weighted3Pool = await create3Pool(tokenA, tokenB, tokenC);

    // Mock addresses for strategies
    longStrategyAddr = addr1.address;
    shortStrategyAddr = addr2.address;
    liquidationStrategyAddr = addr3.address;

    pool = await BalancerGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      factory.address // Address of the WeightedPoolFactory used to create the pool
    );
  });

  async function createPair(token1: any, token2: any) {
    const NAME = "TESTPOOL";
    const SYMBOL = "TP";
    let TOKENS: any;

    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      TOKENS = [token2.address, token1.address];
    } else {
      TOKENS = [token1.address, token2.address];
    }
    const HUNDRETH = BigNumber.from(10).pow(16);
    const WEIGHTS = [
      BigNumber.from(50).mul(HUNDRETH),
      BigNumber.from(50).mul(HUNDRETH),
    ];
    const FEE_PERCENTAGE = HUNDRETH;

    const poolReturnData = await factory.create(
      NAME,
      SYMBOL,
      TOKENS,
      WEIGHTS,
      FEE_PERCENTAGE,
      owner.address
    );

    const receipt = await poolReturnData.wait();
    const events = receipt.events.filter((e: any) => e.event === "PoolCreated");
    const poolAddress = events[0].args.pool;
    return poolAddress;
  }

  async function create3Pool(token1: any, token2: any, token3: any) {
    const NAME = "TESTPOOL";
    const SYMBOL = "TP";
    let TOKENS: any;

    // Sort the token addresses in order
    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      TOKENS = [token2.address, token1.address];
    } else {
      TOKENS = [token1.address, token2.address];
    }

    if (BigNumber.from(token3.address).gt(BigNumber.from(TOKENS[1]))) {
      TOKENS = [...TOKENS, token3.address];
    } else {
      if (BigNumber.from(token3.address).lt(BigNumber.from(TOKENS[0]))) {
        TOKENS = [token3.address, ...TOKENS];
      } else {
        TOKENS = [TOKENS[0], token3.address, TOKENS[1]];
      }
    }

    const HUNDRETH = BigNumber.from(10).pow(16);
    const WEIGHTS = [
      BigNumber.from(10).mul(HUNDRETH),
      BigNumber.from(10).mul(HUNDRETH),
      BigNumber.from(10).pow(18).sub(BigNumber.from(20).mul(HUNDRETH)),
    ];

    const FEE_PERCENTAGE = HUNDRETH;

    const poolReturnData = await factory.create(
      NAME,
      SYMBOL,
      TOKENS,
      WEIGHTS,
      FEE_PERCENTAGE,
      owner.address
    );

    const receipt = await poolReturnData.wait();
    const events = receipt.events.filter((e: any) => e.event === "PoolCreated");
    const poolAddress = events[0].args.pool;
    return poolAddress;
  }

  async function validateCFMM(
    token0: any,
    token1: any,
    cfmm: any,
    gammaPool: any
  ) {
    const data = ethers.utils.defaultAbiCoder.encode([], []);
    const resp = await gammaPool.validateCFMM(
      [token0.address, token1.address],
      cfmm,
      data
    );
    const bigNum0 = BigNumber.from(token0.address);
    const bigNum1 = BigNumber.from(token1.address);
    const token0Addr = bigNum0.lt(bigNum1) ? token0.address : token1.address;
    const token1Addr = bigNum0.lt(bigNum1) ? token1.address : token0.address;
    expect(resp._tokensOrdered[0]).to.equal(token0Addr);
    expect(resp._tokensOrdered[1]).to.equal(token1Addr);
    expect(resp._decimals[0]).to.equal(18);
    expect(resp._decimals[1]).to.equal(18);
  }

  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await pool.protocolId()).to.equal(2);
      expect(await pool.longStrategy()).to.equal(addr1.address);
      expect(await pool.shortStrategy()).to.equal(addr2.address);
      expect(await pool.liquidationStrategy()).to.equal(addr3.address);
      expect(await pool.factory()).to.equal(owner.address);
      expect(await pool.poolFactory()).to.equal(factory.address);
    });
  });

  describe("Validate CFMM", function () {
    it("Error Not Contract", async function () {
      const data = ethers.utils.defaultAbiCoder.encode([], []);
      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], owner.address, data)
      ).to.be.revertedWith("NotContract");
    });

    it("Error Incorrect Token Length", async function () {
      // The WeightedPool given has more than 2 tokens
      const data = ethers.utils.defaultAbiCoder.encode([], []);
      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], weighted3Pool, data)
      ).to.be.revertedWith("IncorrectTokenLength");
    });

    it("Error Incorrect Tokens", async function () {
      // The WeightedPool given has the wrong tokens
      const data = ethers.utils.defaultAbiCoder.encode([], []);
      await expect(
        pool.validateCFMM([tokenA.address, tokenC.address], cfmm, data)
      ).to.be.revertedWith("IncorrectTokens");
    });

    it("Correct Validation #1", async function () {
      await validateCFMM(tokenA, tokenB, cfmm, pool);
    });

    it("Correct Validation #2", async function () {
      const testCFMM = await createPair(tokenA, tokenD);

      const testPool = await BalancerGammaPool.deploy(
        PROTOCOL_ID,
        owner.address,
        longStrategyAddr,
        shortStrategyAddr,
        liquidationStrategyAddr,
        factory.address // Address of the WeightedPoolFactory used to create the pool
      );

      await validateCFMM(tokenA, tokenD, testCFMM, testPool);
    });
  });
});
