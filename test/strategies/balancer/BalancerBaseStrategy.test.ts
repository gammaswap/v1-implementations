import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/deprecated/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/deprecated/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");

describe("BalancerBaseStrategy", function () {
  let TestERC20: any;
  let TestStrategy: any;
  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let vault: any;
  let factory: any;
  let strategy: any;
  let owner: any;

  beforeEach(async function () {
    TestERC20 = await ethers.getContractFactory("TestERC20");
    [owner] = await ethers.getSigners();

    // Get contract factory for WeightedPool: '@balancer-labs/v2-pool-weighted/WeightedPoolFactory'
    // https://github.com/balancer-labs/balancer-v2-monorepo/blob/master/pkg/deployments/tasks/deprecated/20210418-weighted-pool/abi/WeightedPoolFactory.json

    WeightedPoolFactory = new ethers.ContractFactory(
      _WeightedPoolFactoryAbi,
      _WeightedPoolFactoryBytecode.creationCode,
      owner
    );

    // Get contract factory for Vault: '@balancer-labs/v2-vault/contracts/Vault'
    // https://github.com/balancer-labs/balancer-v2-monorepo/blob/master/pkg/deployments/tasks/20210418-vault/artifact/Vault.json
    
    BalancerVault = new ethers.ContractFactory(
      _Vault.abi,
      _Vault.bytecode,
      owner
    );

    TestStrategy = await ethers.getContractFactory("TestBalancerBaseStrategy");

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    
    const HOUR = 60 * 60;
    const DAY = HOUR * 24;
    const MONTH = DAY * 30;

    // Deploy the Vault contract
    vault = await BalancerVault.deploy(owner.address, tokenA.address, MONTH, MONTH);
    
    // Deploy the WeightedPoolFactory contract

    factory = await WeightedPoolFactory.deploy(
        vault.address,
    );
    
    // Create a WeightedPool using the WeightedPoolFactory
    cfmm = await createPair(tokenA, tokenB);

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);
    
    strategy = await TestStrategy.deploy(baseRate, factor, maxApy);

    await (
      await strategy.initialize(
        cfmm,
        [tokenB.address, tokenA.address],
        [18, 18]
      )
    ).wait();
  });

  async function createPair(token1: any, token2: any) {
    const NAME = 'TESTPOOL';
    const SYMBOL = 'TP';
    const TOKENS = [token2.address, token1.address];
    const HUNDRETH = BigNumber.from(10).pow(16);
    const WEIGHTS = [BigNumber.from(50).mul(HUNDRETH), BigNumber.from(50).mul(HUNDRETH)];
    const FEE_PERCENTAGE = HUNDRETH;

    const poolReturnData = await factory.create(
      NAME, SYMBOL, TOKENS, WEIGHTS, FEE_PERCENTAGE, owner.address
    );

    const receipt = await poolReturnData.wait();

    const events = receipt.events.filter((e) => e.event === 'PoolCreated');
    const poolAddress = events[0].args.pool;

    return poolAddress
  }

  describe("Deployment", function () {
    it("Check Init Params", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const baseRate = ONE.div(100);
      const factor = ONE.mul(4).div(100);
      const maxApy = ONE.mul(75).div(100);
      expect(await strategy.baseRate()).to.equal(baseRate);
      expect(await strategy.factor()).to.equal(factor);
      expect(await strategy.maxApy()).to.equal(maxApy);
    });

    // it("Check Invariant Calculation", async function () {
    //   expect(
    //     await strategy.testCalcInvariant(cfmm, [
    //       BigNumber.from(10),
    //       BigNumber.from(10),
    //     ])
    //   ).to.equal(10);

    // });
  });

});
