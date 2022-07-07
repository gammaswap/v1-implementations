import { expect } from "chai";
import { ethers } from "hardhat";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

describe("UniswapV2Module", function () {
  let TestERC20: any;
  let UniswapV2Module: any;
  let UniswapV2Factory: any;
  let uniFactory: any;
  let uniPair: any;
  let uniModule: any;
  let tokenA: any;
  let tokenB: any;
  let owner: any;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    [owner] = await ethers.getSigners();

    TestERC20 = await ethers.getContractFactory("TestERC20");
    UniswapV2Module = await ethers.getContractFactory("UniswapV2Module");

    UniswapV2Factory = new ethers.ContractFactory(
      UniswapV2FactoryJSON.abi,
      UniswapV2FactoryJSON.bytecode,
      owner
    );

    // Deploy, setting total supply to 100 tokens (assigned to the deployer)
    uniFactory = await UniswapV2Factory.deploy(owner.address);

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
    await uniFactory.deployed();

    await uniFactory.createPair(tokenA.address, tokenB.address);

    const uniPairAddress: string = await uniFactory.getPair(
      tokenA.address,
      tokenB.address
    );

    console.log("uniPairAddress >> " + uniPairAddress);
    uniPair = new ethers.Contract(uniPairAddress, UniswapV2PairJSON.abi, owner);
    uniModule = await UniswapV2Module.deploy(uniFactory.address);
  });

  describe("Deployment", function () {
    it("Fields initialized to right values", async function() {
      let token0 = tokenA.address;
      let token1 = tokenB.address;
      if (token0 > token1) {
        token0 = tokenB.address;
        token1 = tokenA.address;
      }
      expect(await uniModule.factory()).to.equal(uniFactory.address);
      expect(await uniPair.factory()).to.equal(uniFactory.address);
      expect(await uniPair.token0()).to.equal(token0);
      expect(await uniPair.token1()).to.equal(token1);
      expect(await uniModule.factory()).to.equal(uniFactory.address);
      expect(await uniModule.getCFMM(tokenA.address, tokenB.address)).to.equal(
        uniPair.address
      );
    });
  });

  describe("CFMM Interaction", function () {
    it("Check add liquidity calculation", async function () {
      //check addLiquidity returns the right numbers and CFMM address
    });
    it("Check it called mint in the CFMM", async function () {
      //The CFMM should have updated its reserves after calling mint (can update to whatever higher number)
    });
  });
});
