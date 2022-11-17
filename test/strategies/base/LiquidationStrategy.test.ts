import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
// import { Address } from "cluster";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

const PROTOCOL_ID = 1;

describe("LiquidationStrategy", function () {
  let TestERC20: any;
  // let TestERC20WithFee: any;
  let TestStrategy: any;
  let TestProtocol: any;
  let UniswapV2Factory: any;
  let UniswapV2Pair: any;
  let tokenA: any;
  let tokenB: any;
  // let tokenAFee: any;
  // let tokenBFee: any;
  let cfmm: any;
  let cfmmFee: any;
  let uniFactory: any;
  let liquidationStrategy: any;
  // let strategyFee: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let protocol: any;
  let tokenId: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    // TestERC20WithFee = await ethers.getContractFactory("TestERC20WithFee");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    UniswapV2Factory = new ethers.ContractFactory(
      UniswapV2FactoryJSON.abi,
      UniswapV2FactoryJSON.bytecode,
      owner
    );
    UniswapV2Pair = new ethers.ContractFactory(
      UniswapV2PairJSON.abi,
      UniswapV2PairJSON.bytecode,
      owner
    );
    TestStrategy = await ethers.getContractFactory("TestCPMMLongStrategy");
    TestProtocol = await ethers.getContractFactory("TestProtocol");
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    uniFactory = await UniswapV2Factory.deploy(owner.address);

    cfmm = await createPair(tokenA, tokenB);

    // because Uniswap's CFMM reorders tokenA and tokenB in increasing order
    const token0addr = await cfmm.token0();
    const token1addr = await cfmm.token1();

    tokenA = await TestERC20.attach(
      token0addr // The deployed contract address
    );
    tokenB = await TestERC20.attach(
      token1addr // The deployed contract address
    );

    protocol = await TestProtocol.deploy(
      PROTOCOL_ID,
      addr1.address,
      addr2.address
    );

    const ONE = BigNumber.from(10).pow(18);
    const baseRate = ONE.div(100);
    const factor = ONE.mul(4).div(100);
    const maxApy = ONE.mul(75).div(100);

    liquidationStrategy = await TestStrategy.deploy(997, 1000, baseRate, factor, maxApy);

    await (
      await liquidationStrategy.initialize(cfmm.address, PROTOCOL_ID, protocol.address, [
        tokenA.address,
        tokenB.address,
      ])
    ).wait();

    const res = await (await liquidationStrategy.createLoan()).wait();
    tokenId = res.events[0].args.tokenId;
  });

  async function createPair(token1: any, token2: any) {
    await uniFactory.createPair(token1.address, token2.address);
    const uniPairAddress: string = await uniFactory.getPair(
      token1.address,
      token2.address
    );

    return await UniswapV2Pair.attach(
      uniPairAddress // The deployed contract address
    );
  }

  describe("Test _liquidate", function () {
    it("returns error HasMargin", async function () {
      await expect(liquidationStrategy._liquidate(tokenId, false, [0, 0])).to.be.revertedWith("HasMargin");
    });

    // it("does not have enough enough margin", async function () {
    //   const ONE = BigNumber.from(10).pow(18);
    //   await (await liquidationStrategy.setLiquidity(tokenId, ONE)).wait();
    //   await liquidationStrategy._liquidate(tokenId, false, [0, 0])
    // //   const ONE = BigNumber.from(10).pow(18);
    // //   const assets = ONE.mul(100);
    // //   const _totalAssets = await strategy.getTotalAssets();
    // //   await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool
    // //   expect(await strategy.getTotalAssets()).to.equal(
    // //     _totalAssets.add(assets)
    // //   );

    // //   const shares = ONE.mul(100);
    // //   const _totalSupply = await strategy.totalSupply();
    // //   await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool
    // //   expect(await strategy.totalSupply()).to.equal(_totalSupply.add(shares));
    // });
  });

  //   it("Check Allowance", async function () {
  //     const allowance = BigNumber.from(100);
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(0);
  //     await (
  //       await strategy.setAllowance(owner.address, strategy.address, allowance)
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(100);

  //     await expect(
  //       strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         allowance.add(1)
  //       )
  //     ).to.be.revertedWith("ExcessiveSpend");

  //     await (
  //       await strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         allowance.div(2)
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(allowance.div(2));

  //     await (
  //       await strategy.setAllowance(
  //         owner.address,
  //         strategy.address,
  //         ethers.constants.MaxUint256
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(ethers.constants.MaxUint256);

  //     await (
  //       await strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         ethers.constants.MaxUint256
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(ethers.constants.MaxUint256);
  //   });
  // });

  // describe("Test _liquidateWithLP()", function () {
  //   it("Check Init Params", async function () {
  //     const ONE = BigNumber.from(10).pow(18);
  //     const assets = ONE.mul(100);
  //     const _totalAssets = await strategy.getTotalAssets();
  //     await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool
  //     expect(await strategy.getTotalAssets()).to.equal(
  //       _totalAssets.add(assets)
  //     );

  //     const shares = ONE.mul(100);
  //     const _totalSupply = await strategy.totalSupply();
  //     await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool
  //     expect(await strategy.totalSupply()).to.equal(_totalSupply.add(shares));
  //   });

  //   it("Check Allowance", async function () {
  //     const allowance = BigNumber.from(100);
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(0);
  //     await (
  //       await strategy.setAllowance(owner.address, strategy.address, allowance)
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(100);

  //     await expect(
  //       strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         allowance.add(1)
  //       )
  //     ).to.be.revertedWith("ExcessiveSpend");

  //     await (
  //       await strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         allowance.div(2)
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(allowance.div(2));

  //     await (
  //       await strategy.setAllowance(
  //         owner.address,
  //         strategy.address,
  //         ethers.constants.MaxUint256
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(ethers.constants.MaxUint256);

  //     await (
  //       await strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         ethers.constants.MaxUint256
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(ethers.constants.MaxUint256);
  //   });
  // });

  // describe("Test payLoanAndRefundLiquidator()", function () {
  //   it("Check Init Params", async function () {
  //     const ONE = BigNumber.from(10).pow(18);
  //     const assets = ONE.mul(100);
  //     const _totalAssets = await strategy.getTotalAssets();
  //     await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool
  //     expect(await strategy.getTotalAssets()).to.equal(
  //       _totalAssets.add(assets)
  //     );

  //     const shares = ONE.mul(100);
  //     const _totalSupply = await strategy.totalSupply();
  //     await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool
  //     expect(await strategy.totalSupply()).to.equal(_totalSupply.add(shares));
  //   });

  //   it("Check Allowance", async function () {
  //     const allowance = BigNumber.from(100);
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(0);
  //     await (
  //       await strategy.setAllowance(owner.address, strategy.address, allowance)
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(100);

  //     await expect(
  //       strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         allowance.add(1)
  //       )
  //     ).to.be.revertedWith("ExcessiveSpend");

  //     await (
  //       await strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         allowance.div(2)
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(allowance.div(2));

  //     await (
  //       await strategy.setAllowance(
  //         owner.address,
  //         strategy.address,
  //         ethers.constants.MaxUint256
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(ethers.constants.MaxUint256);

  //     await (
  //       await strategy.spendAllowance(
  //         owner.address,
  //         strategy.address,
  //         ethers.constants.MaxUint256
  //       )
  //     ).wait();
  //     expect(
  //       await strategy.checkAllowance(owner.address, strategy.address)
  //     ).to.equal(ethers.constants.MaxUint256);
  //   });
  // });
});
