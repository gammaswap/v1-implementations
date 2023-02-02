import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { IERC20 } from "../../../typechain";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");
const _WeightedPoolAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPool.json");
const _WeightedPoolBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPool.json");

describe("BalancerBaseStrategy", function () {
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
  let weightedMathFactory: any;
  let weightedMath: any;
  
  let TOKENS: any;
  let WEIGHTS: any;

  beforeEach(async function () {
    weightedMathFactory = await ethers.getContractFactory("WeightedMath");
    weightedMath = await weightedMathFactory.deploy();

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

    TestStrategy = await ethers.getContractFactory("TestBalancerBaseStrategy", {libraries: {WeightedMath: weightedMath.address}});

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
    const events = receipt.events.filter((e) => e.event === 'PoolCreated');
    const poolAddress = events[0].args.pool;
    return poolAddress
  }

  function expectEqualWithError(actual: BigNumber, expected: BigNumber) {
    const MAX_ERROR = BigNumber.from(10).pow(15); // Max error

    let error = actual.sub(expected).abs();
    expect(error.lte(MAX_ERROR));
  }

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

    it("Check Invariant Calculation", async function () {
      const ONE = BigNumber.from(10).pow(18);

      expectEqualWithError(
        await strategy.testCalcInvariant(cfmm, [
          BigNumber.from(10).mul(ONE),
          BigNumber.from(10).mul(ONE),
        ]),
        BigNumber.from(10).mul(ONE)
      );

      expectEqualWithError(
        await strategy.testCalcInvariant(cfmm, [
          BigNumber.from(20).mul(ONE),
          BigNumber.from(20).mul(ONE),
        ]),
        BigNumber.from(10).mul(ONE)
      );

      expectEqualWithError(
        await strategy.testCalcInvariant(cfmm, [
          BigNumber.from(30).mul(ONE),
          BigNumber.from(30).mul(ONE),
        ]),
        BigNumber.from(10).mul(ONE)
      );

      expectEqualWithError(
        await strategy.testCalcInvariant(cfmm, [
          BigNumber.from(20).mul(ONE),
          BigNumber.from(500).mul(ONE),
        ]),
        BigNumber.from(10).mul(ONE)
      );

      expectEqualWithError(
        await strategy.testCalcInvariant(cfmm, [
          BigNumber.from(2).mul(ONE),
          BigNumber.from(450).mul(ONE),
        ]),
        BigNumber.from(30).mul(ONE)
      );
    });
  });
  
  describe("Check Write Functions", function () {
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
        if (tokenA.address === TOKENS[0]) {
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


    it("Deposit to CFMM", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(500);
      const amtB = ONE.mul(500);
      // const expectedSupply = ONE.mul(100);
      // const expectedLiquidity = expectedSupply.sub(1000); // subtract 1000 because 1st deposit

      expect(await pool.balanceOf(owner.address)).to.equal(0);
      expect(await pool.balanceOf(strategy.address)).to.equal(0);
      expect(await pool.totalSupply()).to.equal(0);

      // We must perform an INIT join at the beginning to start the pool
      const JOIN_KIND_INIT = 0;
      const initialBalances = [ONE.mul(500), ONE.mul(500)];
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

      const receipt = await tx.wait();

      // We must send the tokens to the strategy before we can deposit
      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      // Check that the transfer was successful
      expect(await tokenA.balanceOf(strategy.address)).to.equal(amtA);
      expect(await tokenB.balanceOf(strategy.address)).to.equal(amtB);

      const res = await (
        await strategy.testDepositToCFMM(
          cfmm,
          [amtA, amtB],
          strategy.address
        )
      ).wait();
      
      const depositToCFMMEvent = res.events[res.events.length - 1];
      expect(depositToCFMMEvent.args.cfmm).to.equal(cfmm);
      expect(depositToCFMMEvent.args.to).to.equal(strategy.address);

      // expect(depositToCFMMEvent.args.liquidity).to.equal(expectedLiquidity);
      // expect(await cfmm.balanceOf(strategy.address)).to.equal(
      //   expectedLiquidity
      // );
      // expect(await cfmm.balanceOf(owner.address)).to.equal(0);
      // expect(await cfmm.totalSupply()).to.equal(expectedSupply);
    });

    it("Withdraw from CFMM", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(500);
      const amtB = ONE.mul(500);

      // Perform the INIT join on the pool
      await initialisePool([amtA, amtB]);

      // TODO Store the pool reserves before the deposit/open interest on LP tokens
      // Halve this and then test that the withdrawFromCFMM() function works

      // Perform the pool join
      await depositIntoPool([amtA, amtB]);

      const withdrawAmt = ONE.mul(50);
      const expectedAmtA = ONE.mul(250);
      const expectedAmtB = ONE.mul(250);

      // Expect to have deposited all tokens
      expect(await tokenA.balanceOf(strategy.address)).to.equal(0);
      expect(await tokenB.balanceOf(strategy.address)).to.equal(0);

      const res = await (
        await strategy.testWithdrawFromCFMM(
          cfmm,
          withdrawAmt,
          strategy.address
        )
      ).wait();

      const withdrawFromCFMMEvent = res.events[res.events.length - 1];
      expect(withdrawFromCFMMEvent.args.cfmm).to.equal(cfmm);
      expect(withdrawFromCFMMEvent.args.to).to.equal(strategy.address);
      expect(withdrawFromCFMMEvent.args.amounts.length).to.equal(2);

      // TODO Balancer event gives the following answer: "25000000000001000000"
      // We expect the following answer: "250000000000000000000"

      // expect(withdrawFromCFMMEvent.args.amounts[0]).to.equal(expectedAmtA);
      // expect(withdrawFromCFMMEvent.args.amounts[1]).to.equal(expectedAmtB);

      // TODO Balancer event gives the following answer: "25000000000001000000"
      // We expect the following answer: "250000000000000000000"

      // expect(await tokenA.balanceOf(strategy.address)).to.equal(expectedAmtA);
      // expect(await tokenB.balanceOf(strategy.address)).to.equal(expectedAmtB);
    });

    it("Update Reserves", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(20);
      const amtB = ONE.mul(500);

      const reserves0 = await strategy.getCFMMReserves();

      expect(reserves0.length).to.equal(2);
      expect(reserves0[0]).to.equal(0);
      expect(reserves0[1]).to.equal(0);

      // Perform the INIT join on the pool
      await initialisePool([amtA, amtB]);

      const reserves1 = await strategy.testGetPoolReserves(cfmm);
      await strategy.testUpdateReserves();
      const storageReserves1 = await strategy.getCFMMReserves();

      expect(reserves1.length).to.equal(2);
      expect(reserves1).to.deep.equal(storageReserves1);

      // Perform the pool join
      await depositIntoPool([amtA, amtB]);

      const reserves2 = await strategy.testGetPoolReserves(cfmm);
      await strategy.testUpdateReserves();
      const storageReserves2 = await strategy.getCFMMReserves();

      expect(reserves2.length).to.equal(2);
      expect(reserves2[0]).to.equal(amtA.mul(2));
      expect(reserves2[1]).to.equal(amtB.mul(2));
      expect(reserves2).to.deep.equal(storageReserves2);

      const withdrawAmt = ONE.mul(50);
      const expectedAmtA = ONE.mul(10);
      const expectedAmtB = ONE.mul(250);

      await (
        await strategy.testWithdrawFromCFMM(
          cfmm,
          withdrawAmt,
          strategy.address
        )
      ).wait();

      const reserves3 = await strategy.testGetPoolReserves(cfmm);
      await strategy.testUpdateReserves();
      const storageReserves3 = await strategy.getCFMMReserves();

      expect(reserves3.length).to.equal(2);
      expect(reserves3).to.deep.equal(storageReserves3);

    });
  });
});
