import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { any } from "hardhat/internal/core/params/argumentTypes";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");
const _WeightedPoolAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPool.json");
const _WeightedPoolBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPool.json");

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
  let threePool: any;
  let longStrategyAddr: any;
  let shortStrategyAddr: any;
  let liquidationStrategyAddr: any;

  let cfmm: any;
  let cfmmPool: any;
  let cfmmPoolId: any;
  let cfmmPoolWeights: any;
  let cfmmPoolSwapFeePercentage: any;

  let weighted3Pool: any;
  let cfmmWeighted3Pool: any;
  let cfmmWeighted3PoolId: any;
  let cfmmWeighted3PoolWeights: any;
  let cfmmWeighted3PoolSwapFeePercentage: any;

  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let WeightedPool: any;
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

    WeightedPool = new ethers.ContractFactory(
      _WeightedPoolAbi,
      _WeightedPoolBytecode.creationCode,
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
    
    // Deploy two GammaPool contracts for both separate CFMMs
    cfmmPool = WeightedPool.attach(cfmm);
    cfmmPoolId = await cfmmPool.getPoolId();
    cfmmPoolWeights = await cfmmPool.getNormalizedWeights();
    cfmmPoolSwapFeePercentage = await cfmmPool.getSwapFeePercentage();

    pool = await BalancerGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      factory.address, // Address of the WeightedPoolFactory used to create the pool
      BigNumber.from(50).mul(BigNumber.from(10).pow(16)), // weight0
      cfmmPoolId // poolId
    );

    cfmmWeighted3Pool = WeightedPool.attach(weighted3Pool);
    cfmmWeighted3PoolId = await cfmmWeighted3Pool.getPoolId();
    cfmmWeighted3PoolWeights = await cfmmWeighted3Pool.getNormalizedWeights();
    cfmmWeighted3PoolSwapFeePercentage = await cfmmWeighted3Pool.getSwapFeePercentage();

    threePool = await BalancerGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      factory.address, // Address of the WeightedPoolFactory used to create the pool
      BigNumber.from(10).pow(17), // weight0
      cfmmWeighted3PoolId // poolId
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
    gammaPool: any,
    cfmmPoolId: any, 
    cfmmVault: any, 
    cfmmWeight0: any, 
    cfmmSwapFeePercentage: any
  ) {
    const data = ethers.utils.defaultAbiCoder.encode(['bytes32', 'address', 'uint256', 'uint256'], [cfmmPoolId, cfmmVault, cfmmWeight0, cfmmSwapFeePercentage]);
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
    it("Should Set Correct Initialisation Parameters", async function () {
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
      const data = ethers.utils.defaultAbiCoder.encode(['bytes32', 'address', 'uint256', 'uint256'], [cfmmPoolId, vault.address, cfmmPoolWeights[0], cfmmPoolSwapFeePercentage]);
      
      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], owner.address, data)
      ).to.be.revertedWith("NotContract");
    });

    it("Error Incorrect Token Length", async function () {
      // The WeightedPool given has more than 2 tokens
      const data = ethers.utils.defaultAbiCoder.encode(['bytes32', 'address', 'uint256', 'uint256'], [cfmmWeighted3PoolId, vault.address, cfmmWeighted3PoolWeights[0], cfmmWeighted3PoolSwapFeePercentage]);

      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], weighted3Pool, data)
      ).to.be.revertedWith("IncorrectTokenLength");
    });

    it("Error Incorrect Tokens", async function () {
      // The WeightedPool given has the wrong tokens
      const data = ethers.utils.defaultAbiCoder.encode(['bytes32', 'address', 'uint256', 'uint256'], [cfmmPoolId, vault.address, cfmmPoolWeights[0], cfmmPoolSwapFeePercentage]);

      await expect(
        pool.validateCFMM([tokenA.address, tokenC.address], cfmm, data)
      ).to.be.revertedWith("IncorrectTokens");
    });

    it("Error Incorrect Pool ID", async function () {
      await expect(
        validateCFMM(tokenA, tokenB, cfmm, pool, cfmmWeighted3PoolId, vault.address, cfmmPoolWeights[0], cfmmPoolSwapFeePercentage)
      ).to.be.revertedWith("IncorrectPoolId");
    });

    it("Error Incorrect Vault", async function () {
      await expect(
        validateCFMM(tokenA, tokenB, cfmm, pool, cfmmPoolId, tokenA.address, cfmmPoolWeights[0], cfmmPoolSwapFeePercentage)
      ).to.be.revertedWith("IncorrectVault");
    });

    it("Error Incorrect Swap Fee", async function () {
      await expect(
        validateCFMM(tokenA, tokenB, cfmm, pool, cfmmPoolId, vault.address, cfmmPoolWeights[0], BigNumber.from(10).pow(17))
      ).to.be.revertedWith("IncorrectSwapFee");
    });

    it("Error Incorrect Weights", async function () {
      await expect(
        validateCFMM(tokenA, tokenB, cfmm, pool, cfmmPoolId, vault.address, cfmmWeighted3PoolWeights[0], cfmmPoolSwapFeePercentage)
      ).to.be.revertedWith("IncorrectWeights");
    });

    it("Correct Validation #1", async function () {
      await validateCFMM(tokenA, tokenB, cfmm, pool, cfmmPoolId, vault.address, cfmmPoolWeights[0], cfmmPoolSwapFeePercentage);
    });

    it("Correct Validation #2", async function () {
      const testCFMM = await createPair(tokenA, tokenD);

      let testCfmm = await WeightedPool.attach(testCFMM);
      let testCfmmPoolId = await testCfmm.getPoolId();

      const testPool = await BalancerGammaPool.deploy(
        PROTOCOL_ID,
        owner.address,
        longStrategyAddr,
        shortStrategyAddr,
        liquidationStrategyAddr,
        factory.address, // Address of the WeightedPoolFactory used to create the pool
        BigNumber.from(50).pow(17), // weight0
        testCfmmPoolId // poolId
      );

      await validateCFMM(tokenA, tokenD, testCFMM, testPool, testCfmmPoolId, vault.address, BigNumber.from(5).mul(BigNumber.from(10).pow(17)), BigNumber.from(10).pow(16));
    });
  });
});
