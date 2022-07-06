import { expect } from "chai";
import { ethers } from "hardhat";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

describe("UniswapV2Router", function () {
  let TestERC20: any;
  let UniswapV2Router: any;
  let UniswapV2Factory: any;
  let uniFactory: any;
  let uniPair: any;
  let uniRouter: any;
  let tokenA: any;
  let tokenB: any;
  let owner: any;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    [owner] = await ethers.getSigners();

    TestERC20 = await ethers.getContractFactory("TestERC20");
    UniswapV2Router = await ethers.getContractFactory("TestUniswapV2Router");

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
    uniRouter = await UniswapV2Router.deploy(uniFactory.address);
  });

  describe("Deployment", function () {
    it("Fields initialized to right values", async function () {
      let token0 = tokenA.address;
      let token1 = tokenB.address;
      if (token0 > token1) {
        token0 = tokenB.address;
        token1 = tokenA.address;
      }
      expect(await uniRouter.factory()).to.equal(uniFactory.address);
      expect(await uniPair.factory()).to.equal(uniFactory.address);
      expect(await uniPair.token0()).to.equal(token0);
      expect(await uniPair.token1()).to.equal(token1);
      expect(await uniRouter.factory()).to.equal(uniFactory.address);
      expect(
        await uniRouter.testPairFor(tokenA.address, tokenB.address)
      ).to.equal(uniPair.address);
    });

    it("Should return the new greeting once it's changed", async function () {
      const Greeter = await ethers.getContractFactory("Greeter");
      const greeter = await Greeter.deploy("Hello, world!");
      await greeter.deployed();

      expect(await greeter.greet()).to.equal("Hello, world!");

      const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

      // wait until the transaction is mined
      await setGreetingTx.wait();

      expect(await greeter.greet()).to.equal("Hola, mundo!");
    });
  });
});
