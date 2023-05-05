import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");
const _WeightedPoolAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPool.json");
const _WeightedPoolBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPool.json");

// Protocol ID for Balancer
const PROTOCOL_ID = 2;

describe.skip("BalancerGammaPool", function () {
  let TestERC20: any;
  let BalancerGammaPool: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let tokenD: any;
  let owner: any;
  let pool: any;
  let longStrategy: any;
  let shortStrategy: any;
  let liquidationStrategy: any;

  let cfmm: any;
  let cfmmPool: any;
  let cfmmPoolId: any;
  let cfmmPoolWeights: any;

  let weighted3Pool: any;
  let cfmmWeighted3Pool: any;
  let cfmmWeighted3PoolId: any;
  let cfmmWeighted3PoolWeights: any;

  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let WeightedPool: any;
  let vault: any;
  let factory: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    const fixedPointFactory = await ethers.getContractFactory("FixedPoint");
    const fixedPoint = await fixedPointFactory.deploy();

    TestERC20 = await ethers.getContractFactory("TestERC20");
    BalancerGammaPool = await ethers.getContractFactory("BalancerGammaPool", {
      libraries: {
        FixedPoint: fixedPoint.address,
      },
    });

    // Fetch contract factories for strategies
    shortStrategy = await ethers.getContractFactory("BalancerShortStrategy", {
      libraries: {
        FixedPoint: fixedPoint.address,
      },
    });
    longStrategy = await ethers.getContractFactory(
      "BalancerExternalLongStrategy",
      {
        libraries: {
          FixedPoint: fixedPoint.address,
        },
      }
    );
    liquidationStrategy = await ethers.getContractFactory(
      "BalancerExternalLiquidationStrategy",
      {
        libraries: {
          FixedPoint: fixedPoint.address,
        },
      }
    );

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

    [owner] = await ethers.getSigners();

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

    // Deploy two GammaPool contracts for both separate CFMMs
    cfmmPool = WeightedPool.attach(cfmm);
    cfmmPoolId = await cfmmPool.getPoolId();
    cfmmPoolWeights = await cfmmPool.getNormalizedWeights();

    // Deploy strategies
    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    longStrategy = await longStrategy.deploy(
      10,
      BigNumber.from(800),
      BigNumber.from(10).pow(19),
      BigNumber.from(2252571),
      BigNumber.from(0),
      baseRate,
      factor,
      maxApy,
      cfmmPoolWeights[0]
    );

    shortStrategy = await shortStrategy.deploy(
      BigNumber.from(10).pow(19),
      BigNumber.from(2252571),
      baseRate,
      factor,
      maxApy,
      cfmmPoolWeights[0]
    );

    liquidationStrategy = await liquidationStrategy.deploy(
      10,
      BigNumber.from(800),
      BigNumber.from(1),
      BigNumber.from(10).pow(19),
      BigNumber.from(2252571),
      baseRate,
      factor,
      maxApy,
      cfmmPoolWeights[0]
    );

    pool = await BalancerGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategy.address,
      shortStrategy.address,
      liquidationStrategy.address,
      factory.address, // Address of the WeightedPoolFactory used to create the pool
      cfmmPoolWeights[0] // weight0
    );

    cfmmWeighted3Pool = WeightedPool.attach(weighted3Pool);
    cfmmWeighted3PoolId = await cfmmWeighted3Pool.getPoolId();
    cfmmWeighted3PoolWeights = await cfmmWeighted3Pool.getNormalizedWeights();
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

  function sort2Tokens(token1: any, token2: any) {
    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      return [token2.address, token1.address];
    } else {
      return [token1.address, token2.address];
    }
  }

  async function validateCFMM(
    token0: any,
    token1: any,
    cfmm: any,
    gammaPool: any,
    cfmmPoolId: any,
    cfmmVault: any,
    cfmmWeight0: any
  ) {
    const data = ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "address", "uint256"],
      [cfmmPoolId, cfmmVault, cfmmWeight0]
    );
    const tokensOrdered = await gammaPool.validateCFMM(
      [token0.address, token1.address],
      cfmm,
      data
    );

    const bigNum0 = BigNumber.from(token0.address);
    const bigNum1 = BigNumber.from(token1.address);
    const token0Addr = bigNum0.lt(bigNum1) ? token0.address : token1.address;
    const token1Addr = bigNum0.lt(bigNum1) ? token1.address : token0.address;
    expect(tokensOrdered[0]).to.equal(token0Addr);
    expect(tokensOrdered[1]).to.equal(token1Addr);
  }

  describe("Deployment", function () {
    it("Should Set Correct Initialisation Parameters", async function () {
      expect(await pool.protocolId()).to.equal(2);
      expect(await pool.longStrategy()).to.equal(longStrategy.address);
      expect(await pool.shortStrategy()).to.equal(shortStrategy.address);
      expect(await pool.liquidationStrategy()).to.equal(
        liquidationStrategy.address
      );
      expect(await pool.factory()).to.equal(owner.address);
      expect(await pool.poolFactory()).to.equal(factory.address);
    });
  });

  describe("Validate CFMM", function () {
    it("Error Not Contract", async function () {
      const data = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "address", "uint256"],
        [cfmmPoolId, vault.address, cfmmPoolWeights[0]]
      );

      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], owner.address, data)
      ).to.be.revertedWithCustomError(pool, "NotContract");
    });

    it("Error Incorrect Token Length", async function () {
      // The WeightedPool given has more than 2 tokens
      const data = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "address", "uint256"],
        [cfmmWeighted3PoolId, vault.address, cfmmWeighted3PoolWeights[0]]
      );

      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], weighted3Pool, data)
      ).to.be.revertedWithCustomError(pool, "IncorrectTokenLength");
    });

    it("Error Incorrect Tokens", async function () {
      // The WeightedPool given has the wrong tokens
      const data = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "address", "uint256"],
        [cfmmPoolId, vault.address, cfmmPoolWeights[0]]
      );

      await expect(
        pool.validateCFMM([tokenA.address, tokenC.address], cfmm, data)
      ).to.be.revertedWithCustomError(pool, "IncorrectTokens");
    });

    it("Error Incorrect Pool ID", async function () {
      await expect(
        validateCFMM(
          tokenA,
          tokenB,
          cfmm,
          pool,
          cfmmWeighted3PoolId,
          vault.address,
          cfmmPoolWeights[0]
        )
      ).to.be.revertedWithCustomError(pool, "IncorrectPoolId");
    });

    it("Error Incorrect Vault", async function () {
      await expect(
        validateCFMM(
          tokenA,
          tokenB,
          cfmm,
          pool,
          cfmmPoolId,
          tokenA.address,
          cfmmPoolWeights[0]
        )
      ).to.be.revertedWithCustomError(pool, "IncorrectVaultAddress");
    });

    it("Error Incorrect Weights", async function () {
      await expect(
        validateCFMM(
          tokenA,
          tokenB,
          cfmm,
          pool,
          cfmmPoolId,
          vault.address,
          cfmmWeighted3PoolWeights[0]
        )
      ).to.be.revertedWithCustomError(pool, "IncorrectWeights");
    });

    it("Correct Validation #1", async function () {
      await validateCFMM(
        tokenA,
        tokenB,
        cfmm,
        pool,
        cfmmPoolId,
        vault.address,
        cfmmPoolWeights[0]
      );
    });

    it("Correct Validation #2", async function () {
      const testCFMM = await createPair(tokenA, tokenD);

      const testCfmm = await WeightedPool.attach(testCFMM);
      const testCfmmPoolId = await testCfmm.getPoolId();

      const testPool = await BalancerGammaPool.deploy(
        PROTOCOL_ID,
        owner.address,
        longStrategy.address,
        shortStrategy.address,
        liquidationStrategy.address,
        factory.address, // Address of the WeightedPoolFactory used to create the pool
        cfmmPoolWeights[0] // weight0
      );

      await validateCFMM(
        tokenA,
        tokenD,
        testCFMM,
        testPool,
        testCfmmPoolId,
        vault.address,
        BigNumber.from(5).mul(BigNumber.from(10).pow(17))
      );
    });
  });

  describe("Initialize BalancerGammaPool", function () {
    it("Initializes Correctly", async function () {
      const data = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "address", "uint256"],
        [cfmmPoolId, vault.address, cfmmPoolWeights[0]]
      );

      await pool.initialize(
        cfmmPool.address,
        sort2Tokens(tokenA, tokenB),
        [18, 18],
        data
      );

      expect(await pool.weight0()).to.equal(cfmmPoolWeights[0]);
      // expect(await pool.getPoolId()).to.equal(cfmmPoolId);
      // expect(await pool.getScalingFactors()).to.deep.equal([
      //  BigNumber.from(1),
      //  BigNumber.from(1),
      // ]);
    });

    it("Initializes Correctly with Scaling Factors", async function () {
      const data = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "address", "uint256"],
        [cfmmPoolId, vault.address, cfmmPoolWeights[0]]
      );

      await pool.initialize(
        cfmmPool.address,
        sort2Tokens(tokenA, tokenB),
        [6, 12],
        data
      );

      expect(await pool.weight0()).to.equal(cfmmPoolWeights[0]);
      /* expect(await pool.getPoolId()).to.equal(cfmmPoolId);
      expect(await pool.getScalingFactors()).to.deep.equal([
        BigNumber.from(10).pow(12),
        BigNumber.from(10).pow(6),
      ]);/**/
    });
  });
});
