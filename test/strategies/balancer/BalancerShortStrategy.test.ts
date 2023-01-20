import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");
const _WeightedPoolAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPool.json");
const _WeightedPoolBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPool.json");

describe("BalancerShortStrategy", function () {
  let TestERC20: any;
  let TestStrategy: any;
  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let WeightedPool: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let vault: any;
  let factory: any;
  let strategy: any;
  let owner: any;
  let pool: any;
  let poolId: any;

  let TOKENS: any;
  let WEIGHTS: any;

  beforeEach(async function () {
    TestERC20 = await ethers.getContractFactory("TestERC20");
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

    TestStrategy = await ethers.getContractFactory("TestBalancerShortStrategy");

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

    pool = WeightedPool.attach(cfmm);
    poolId = await pool.getPoolId();

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);
    
    strategy = await TestStrategy.deploy(baseRate, factor, maxApy);
    
    console.log('Initializing strategy: ', strategy.address);
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
    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      TOKENS = [token2.address, token1.address];
    }
    else {
      TOKENS = [token1.address, token2.address];
    }
    const HUNDRETH = BigNumber.from(10).pow(16);
    WEIGHTS = [BigNumber.from(50).mul(HUNDRETH), BigNumber.from(50).mul(HUNDRETH)];
    const FEE_PERCENTAGE = HUNDRETH;

    const poolReturnData = await factory.create(
      NAME, SYMBOL, TOKENS, WEIGHTS, FEE_PERCENTAGE, owner.address
    );

    const receipt = await poolReturnData.wait();

    // console.log('RECEIPT:', receipt);

    const events = receipt.events.filter((e) => e.event === 'PoolCreated');
    
    // console.log('EVENTS:', events);

    const poolAddress = events[0].args.pool;

    console.log('POOL ADDRESS: ', poolAddress);

    return poolAddress
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const baseRate = ONE.div(100);
      const factor = ONE.mul(4).div(100);
      const maxApy = ONE.mul(75).div(100);

      // Check strategy params are correct
      expect(await strategy.baseRate()).to.equal(baseRate);
      expect(await strategy.factor()).to.equal(factor);
      expect(await strategy.maxApy()).to.equal(maxApy);

      // Check the strategy parameters align
      const HUNDRETH = BigNumber.from(10).pow(16);
      const WEIGHTS = [BigNumber.from(50).mul(HUNDRETH), BigNumber.from(50).mul(HUNDRETH)];

      expect(pool.address).to.equal(cfmm);
      expect(await strategy.getCFMM()).to.equal(cfmm);
      expect(await strategy.getCFMMReserves()).to.deep.equal([BigNumber.from(0), BigNumber.from(0)]);
      expect(await strategy.testGetVault(cfmm)).to.equal(await pool.getVault());
      expect(await strategy.testGetTokens(cfmm)).to.deep.equal(TOKENS);
      expect(await strategy.testGetPoolId(cfmm)).to.equal(poolId);
      expect(await pool.getNormalizedWeights()).to.deep.equal(WEIGHTS);
      expect(await strategy.testGetWeights(cfmm)).to.deep.equal(WEIGHTS);
    });
  });

  describe("Calc Deposit Amounts Functions", function () {
    async function initialisePool(initialBalances: any) {
      // We must perform an INIT join at the beginning to start the pool
      const JOIN_KIND_INIT = 0;
      const initUserData = ethers.utils.defaultAbiCoder.encode(['uint256', 'uint256[]'], [JOIN_KIND_INIT, initialBalances]);

      // 'ERC20: insufficient allowance'
      // We must approve the vault to spend the tokens we own
      await tokenA.approve(vault.address, ethers.constants.MaxUint256);
      await tokenB.approve(vault.address, ethers.constants.MaxUint256);

      const joinPoolRequest = {
        assets: TOKENS,
        maxAmountsIn: initialBalances,
        userData: initUserData,
        fromInternalBalance: false
      } 

      const tx = await vault.joinPool(poolId, owner.address, owner.address, joinPoolRequest);
    } 

  async function depositIntoPool(amounts: any) {
      // We must send the tokens to the strategy before we can deposit
      // We must send tokens in the correct orientation
      if (TOKENS[0] == tokenA.address) {
      await tokenA.transfer(strategy.address, amounts[0]);
      await tokenB.transfer(strategy.address, amounts[1]);
      } else {
      await tokenA.transfer(strategy.address, amounts[1]);
      await tokenB.transfer(strategy.address, amounts[0]);
      }

      const res = await (
        await strategy.testDepositToCFMM(
          cfmm,
          amounts,
          strategy.address
        )
      ).wait();

    return 1
  }

    it("Check Optimal Amt", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amountOptimal = ONE.mul(100);
      const amountMin = amountOptimal.add(1);

      await expect(
        strategy.testCheckOptimalAmt(amountOptimal, amountMin)
      ).to.be.revertedWith("NotOptimalDeposit");

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

      console.log("Checking that the reserves are 0 at the start");
      const res0 = await strategy.testGetReserves(cfmm);
      expect(res0.length).to.equal(2);
      expect(res0[0]).to.equal(0);
      expect(res0[1]).to.equal(0);
      console.log("Reserves are 0 at the start");

      console.log("Initialising the pool with 20 A and 500 B");
      await initialisePool([amtA, amtB]);

      console.log("Checking that the reserves are 20 A and 500 B");
      const res1 = await strategy.testGetReserves(cfmm);
      console.log(res1);
      expect(res1.length).to.equal(2);
      expect(res1[0]).to.equal(amtA);
      expect(res1[1]).to.equal(amtB);
      console.log("Reserves are 20 A and 500 B");

      console.log("Depositing 20 A and 500 B into the pool");

      await depositIntoPool([amtA, amtB]);

      console.log("Checking that the reserves are 40 A and 1000 B")
      const res2 = await strategy.testGetReserves(cfmm);
      expect(res2.length).to.equal(2);
      expect(res2[0]).to.equal(amtA.mul(2));
      expect(res2[1]).to.equal(amtB.mul(2));
      console.log("Reserves are 40 A and 1000 B");

      console.log('Calling withdrawFromCFMM():');
      const withdrawAmt = ONE.mul(50);

      const res = await (
        await strategy.testWithdrawFromCFMM(
          cfmm,
          withdrawAmt,
          strategy.address
        )
      ).wait();

      const res3 = await strategy.testGetReserves(cfmm);

      console.log("Post-withdrawal reserves:")
      console.log(res3);
      
      // const cfmmTokens = ethers.Contract(cfmm, ).attach(cfmm);
      // console.log(await cfmmTokens.balanceOf(strategy.address));

      expect(res2.length).to.equal(2);
      expect(res2[0]).to.equal(amtA.mul(2));
      expect(res2[1]).to.equal(amtB.mul(2));

      // await (await cfmm.transfer(cfmm.address, ONE.mul(50))).wait();
      // await (await cfmm.burn(owner.address)).wait();

      // const res3 = await strategy.testGetReserves(cfmm.address);
      // expect(res3.length).to.equal(2);
      // expect(res3[0]).to.equal(amtA.mul(2).sub(amtA.div(2)));
      // expect(res3[1]).to.equal(amtB.mul(2).sub(amtB.div(2)));
    });

    it("Error Calc Deposit Amounts, 0 amt", async function () {
      await expect(
        strategy.testCalcDeposits([0, 0], [0, 0])
      ).to.be.revertedWith("ZeroDeposits");
      await expect(
        strategy.testCalcDeposits([1, 0], [0, 0])
      ).to.be.revertedWith("ZeroDeposits");
      await expect(
        strategy.testCalcDeposits([0, 1], [0, 0])
      ).to.be.revertedWith("ZeroDeposits");
    });

    it("Error Calc Deposit Amounts, 0 reserve tokens", async function () {
      const amountsDesired = [BigNumber.from(1), BigNumber.from(1)];
      const result = await strategy.testCalcDeposits(amountsDesired, [0, 0]);

      console.log("Amounts: ", result.amounts);
      console.log("Payee: ", result.payee);

      expect(result.amounts).to.deep.equal(amountsDesired);
      expect(result.payee).to.equal(strategy.address);
    });

    // TODO: I don't believe that these tests can actually occur with Balancer
    
    // it("Error Calc Deposit Amounts, 0 reserve tokenA", async function () {
    //   // await (await tokenB.transfer(cfmm, 1)).wait();
    //   // await (await cfmm.sync()).wait();
    //   await expect(
    //     strategy.testCalcDeposits([1, 1], [0, 0])
    //   ).to.be.revertedWith("ZeroReserves");
    // });

    // it("Error Calc Deposit Amounts, 0 reserve tokenB", async function () {
    //   // await (await tokenA.transfer(cfmm, 1)).wait();
    //   // await (await cfmm.sync()).wait();
    //   await expect(
    //     strategy.testCalcDeposits([1, 1], [0, 0])
    //   ).to.be.revertedWith("ZeroReserves");
    // });

    it("Error Calc Deposit Amounts, < minAmt", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(20);
      const amtB = ONE.mul(20);
      await initialisePool([amtA, amtB]);

      await expect(
        strategy.testCalcDeposits([amtA, amtB], [0, amtB.mul(2)])
      ).to.be.revertedWith("NotOptimalDeposit");

      // TODO: Test that this is reverted with the correct error message
      // What is this testing for?

      // await expect(
      //   strategy.testCalcDeposits([amtA, amtB], [amtA.mul(2), 0])
      // ).to.be.revertedWith("NotOptimalDeposit");
    });

    it("Empty reserves", async function () {
      const res = await strategy.testCalcDeposits([1, 1], [0, 0]);
      expect(res.amounts.length).to.equal(2);
      expect(res.amounts[0]).to.equal(1);
      expect(res.amounts[1]).to.equal(1);
      expect(res.payee).to.equal(strategy.address);
    });

    it("Test Successful Calculation #1", async function () {
      const ONE = BigNumber.from(10).pow(18);
      await initialisePool([ONE.mul(100), ONE.mul(100)]);

      const res = await strategy.testCalcDeposits(
        [ONE.mul(100), ONE.mul(100)],
        [0, 0]
      );

      expect(res.amounts.length).to.equal(2);
      expect(res.amounts[0]).to.equal(ONE.mul(100));
      expect(res.amounts[1]).to.equal(ONE.mul(100));
      expect(res.payee).to.equal(strategy.address);
    });

    it("Test Successful Calculation #2", async function () {
      const ONE = BigNumber.from(10).pow(18);
      await initialisePool([ONE.mul(50), ONE.mul(100)]);

      const res = await strategy.testCalcDeposits(
        [ONE.mul(100), ONE.mul(130)],
        [0, 0]
      );

      expect(res.amounts.length).to.equal(2);
      expect(res.amounts[0]).to.equal(ONE.mul(65));
      expect(res.amounts[1]).to.equal(ONE.mul(130));
      expect(res.payee).to.equal(strategy.address);
    });

    it("Test Successful Calculation #3", async function () {
      const ONE = BigNumber.from(10).pow(18);
      await initialisePool([ONE.mul(400), ONE.mul(100)]);

      const res = await strategy.testCalcDeposits(
        [ONE.mul(200), ONE.mul(200)],
        [0, 0]
      );

      expect(res.amounts.length).to.equal(2);
      expect(res.amounts[0]).to.equal(ONE.mul(200));
      expect(res.amounts[1]).to.equal(ONE.mul(50));
      expect(res.payee).to.equal(strategy.address);
    });

  });
});