import { ethers } from "hardhat";
import { expect } from "chai";

describe("Short Strategy", function () {
  let TestERC20;
  let TestPoolAddress: any;
  let TestProtocol: any;
  let TestShortStrategy: any;
  let testShortStrategy: any;
  let GammaPool: any;
  let GammaPoolFactory: any;
  let factory: any;
  let testPoolAddress: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let gammaPool: any;
  let gammaPoolAddr: any;
  let protocol: any;
  let protocolZero: any;

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestPoolAddress = await ethers.getContractFactory("TestPoolAddress");
    TestProtocol = await ethers.getContractFactory("TestProtocol");
    GammaPool = await ethers.getContractFactory("GammaPool");
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
    TestShortStrategy = await ethers.getContractFactory("TestShortStrategy");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    testPoolAddress = await TestPoolAddress.deploy();
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    cfmm = await TestERC20.deploy("CFMM LP Token", "LP_CFMM");
    testShortStrategy = await TestShortStrategy.deploy();
    protocol = await TestProtocol.deploy(addr1.address, addr2.address, 1);
    protocolZero = await TestProtocol.deploy(addr1.address, addr2.address, 0);

    factory = await GammaPoolFactory.deploy(owner.address);

    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
    await protocol.deployed();
    await protocolZero.deployed();

    await factory.addProtocol(protocol.address);

    console.log(ethers.utils.keccak256(GammaPool.bytecode));

    const createPoolParams = {
      cfmm: cfmm.address,
      protocol: 1,
      tokens: [tokenA.address, tokenB.address]
    };

    const res = await (await factory.createPool(createPoolParams)).wait();
    const { args } = res.events[0];
    gammaPoolAddr = args.pool; // The deployed contract address

  });

  // You can nest describe calls to create subsections.
  context("Deployment", function () {
    it("Should set the right owner", async function () {
        expect(await tokenA.owner()).to.equal(owner.address);
        expect(await tokenB.owner()).to.equal(owner.address);
      });
  });

  context("Functions", function () {
    it("Should deposit", async function () {
        const res = await (await testShortStrategy._depositNoPull(owner.address)).wait();
    });
  });
});
