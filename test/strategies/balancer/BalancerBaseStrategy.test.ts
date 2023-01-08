import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { deployContract } from "ethereum-waffle";

const _Vault = require("@balancer-labs/v2-deployments/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPooLFactory = require("@balancer-labs/v2-deployments/tasks/20220908-weighted-pool-v2/artifact/WeightedPoolFactory.json");

describe("BalancerBaseStrategy", function () {
  let TestERC20: any;
  let TestStrategy: any;
  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let tokenA: any;
  let tokenB: any;
  let WETH: any;
  let cfmm: any;
  // let balancerVault: any;
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

    WeightedPoolFactory = new ethers.ContractFactory(
      _WeightedPooLFactory.abi,
      _WeightedPooLFactory.bytecode,
      owner
    );

    // TODO: Get contract factory for Vault: '@balancer-labs/v2-vault/contracts/Vault'
    // https://github.com/balancer-labs/balancer-v2-monorepo/blob/master/pkg/deployments/tasks/20210418-vault/artifact/Vault.json

    BalancerVault = new ethers.ContractFactory(
      _Vault.abi,
      _Vault.bytecode,
      owner
    );

    TestStrategy = await ethers.getContractFactory("TestBalancerBaseStrategy");

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    WETH = await TestERC20.deploy("Wrapped Ether", "WETH");

    // TODO: Deploy the Vault contract
    
    // TODO: Create a WeightedPool using the WeightedPoolFactory
    // cfmm = await createPair(tokenA, tokenB);

    // const factory = await deploy('@balancer-labs/v2-pool-weighted/WeightedPoolFactory', {
    //   args: [
    //     vault.address,
    //     vault.getFeesProvider().address,
    //     BASE_PAUSE_WINDOW_DURATION,
    //     BASE_BUFFER_PERIOD_DURATION,
    //   ],
    //   owner,
    // });

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    strategy = await TestStrategy.deploy(baseRate, factor, maxApy);
    await (
      await strategy.initialize(
        cfmm.address,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();
  });

  async function createPair(token1: any, token2: any) {
    // const tx = await factory.create(
    //   NAME,
    //   SYMBOL,
    //   tokens.addresses,
    //   weights,
    //   rateProviders,
    //   swapFeePercentage,
    //   owner
    // );
    // const receipt = await tx.wait();
    // const event = expectEvent.inReceipt(receipt, 'PoolCreated');
    // result = deployedAt('v2-pool-weighted/WeightedPool', event.args.pool);
  }

  describe("Deployment", function () {
    it("Check Init Params", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const baseRate = ONE.div(100);
      const factor = ONE.mul(4).div(100);
      const maxApy = ONE.mul(75).div(100);
      // expect(await strategy.baseRate()).to.equal(baseRate);
      // expect(await strategy.factor()).to.equal(factor);
      // expect(await strategy.maxApy()).to.equal(maxApy);
    });
  });

});
