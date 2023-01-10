import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { deployContract } from "ethereum-waffle";
import { int } from "hardhat/internal/core/params/argumentTypes";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPooLFactory = require("@balancer-labs/v2-deployments/dist/tasks/20220908-weighted-pool-v2/artifact/WeightedPoolFactory.json");

describe("BalancerBaseStrategy", function () {
  let TestERC20: any;
  let TestStrategy: any;
  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let tokenA: any;
  let tokenB: any;
  let WETH: any;
  let cfmm: any;
  let vault: any;
  let factory: any;
  let strategy: any;
  let owner: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    [owner] = await ethers.getSigners();

    // TODO: Get contract factory for WeightedPool: '@balancer-labs/v2-pool-weighted/WeightedPoolFactory'
    // https://github.com/balancer-labs/balancer-v2-monorepo/blob/master/pkg/deployments/tasks/20220908-weighted-pool-v2/artifact/WeightedPoolFactory.json

    console.log('Getting WeightedPoolFactory contract factory');
    WeightedPoolFactory = new ethers.ContractFactory(
      _WeightedPooLFactory.abi,
      _WeightedPooLFactory.bytecode,
      owner
    );

    // TODO: Get contract factory for Vault: '@balancer-labs/v2-vault/contracts/Vault'
    // https://github.com/balancer-labs/balancer-v2-monorepo/blob/master/pkg/deployments/tasks/20210418-vault/artifact/Vault.json
    
    console.log('Getting Vault contract factory');
    BalancerVault = new ethers.ContractFactory(
      _Vault.abi,
      _Vault.bytecode,
      owner
    );

    TestStrategy = await ethers.getContractFactory("TestBalancerBaseStrategy");

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    WETH = await TestERC20.deploy("Wrapped Ether", "WETH");
    
    console.log('Deploying Vault contract');
    // TODO: Deploy the Vault contract
    const HOUR = 60 * 60;
    const DAY = HOUR * 24;
    const MONTH = DAY * 30;

    vault = await BalancerVault.deploy(owner.address, WETH.address, MONTH, MONTH);
    
    console.log('Vault address: ', vault.address);

    console.log('Deploying WeightedPoolFactory contract');
    // TODO: Deploy the WeightedPoolFactory contract
    factory = await WeightedPoolFactory.deploy(
        vault.address,
        '0x0000000000000000000000000000000000000000'
    );

    console.log('Factory address: ', factory.address);
    console.log('Factory vault address: ', await factory.getVault());
    
    console.log('Creating WeightedPool using createPair()')
    // TODO: Create a WeightedPool using the WeightedPoolFactory
    cfmm = await createPair(tokenA, tokenB);

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    console.log('Deploying TestBalancerBaseStrategy contract')
    strategy = await TestStrategy.deploy(baseRate, factor, maxApy);
    await (
      await strategy.initialize(
        cfmm,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();
  });

  async function createPair(token1: any, token2: any) {
    const NAME = 'TESTPOOL';
    const SYMBOL = 'TP';

    const token1_decimals = parseInt(token1.address, 16);
    const token2_decimals = parseInt(token2.address, 16);

    let TOKENS = [];

    // Tokens must be sorted numerically by address
    if (token1_decimals > token2_decimals)
    {
      TOKENS = [token2.address, token1.address];
    }
    else
    {
      TOKENS = [token1.address, token2.address];
    }

    console.log(TOKENS)

    const WEIGHTS = [0.5e18, 0.5e18];
    const FEE_PERCENTAGE = 0.005e18;
    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

    console.log('Creating WeightedPool using WeightedPoolFactory.create()');
    const tx = await factory.create(
      NAME, SYMBOL, TOKENS, WEIGHTS, [ZERO_ADDRESS], FEE_PERCENTAGE, owner
    );

    console.log('Getting receipt...');
    const receipt = await tx.wait();
    // We need to get the new pool address out of the PoolCreated event
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
  });

});
