import { ethers } from "hardhat";
import { expect } from "chai";

describe("GammaPool", function () {
  let TestERC20;
  let TestPoolAddress: any;
  let TestProtocol: any;
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
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestPoolAddress = await ethers.getContractFactory("TestPoolAddress");
    TestProtocol = await ethers.getContractFactory("TestProtocol");
    GammaPool = await ethers.getContractFactory("GammaPool");
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    testPoolAddress = await TestPoolAddress.deploy();
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    cfmm = await TestERC20.deploy("CFMM LP Token", "LP_CFMM");
    protocol = await TestProtocol.deploy(addr1.address, addr2.address, 1);
    protocolZero = await TestProtocol.deploy(addr1.address, addr2.address, 0);

    factory = await GammaPoolFactory.deploy(owner.address);

    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
    await protocol.deployed();
    await protocolZero.deployed();

    await factory.addProtocol(protocol.address);

    const createPoolParams = {
      cfmm: cfmm.address,
      protocol: 1,
      tokens: [tokenA.address, tokenB.address]
    };

    const res = await (await factory.createPool(createPoolParams)).wait();
    const { args } = res.events[0];
    gammaPoolAddr = args.pool; // The deployed contract address


    gammaPool = await GammaPool.attach(
      gammaPoolAddr
    );
  });

  // You can nest describe calls to create subsections.
  context("Deployment", function () {
    // `it` is another Mocha function. This is the one you use to define your
    // tests. It receives the test name, and a callback function.

    // If the callback function is async, Mocha will `await` it.
    it("Should set the right owner", async function () {
      // Expect receives a value, and wraps it in an assertion objet. These
      // objects have a lot of utility methods to assert values.

      // This test expects the owner variable stored in the contract to be equal
      // to our Signer's owner.
      expect(await tokenA.owner()).to.equal(owner.address);
      expect(await tokenB.owner()).to.equal(owner.address);
    });

    it("Should be right INIT_CODE_HASH", async function () {
      const COMPUTED_INIT_CODE_HASH = ethers.utils.keccak256(
        GammaPool.bytecode
      );
      expect(COMPUTED_INIT_CODE_HASH).to.equal(
        await testPoolAddress.getInitCodeHash()
      );
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await tokenA.balanceOf(owner.address);
      expect(await tokenA.totalSupply()).to.equal(ownerBalance);
    });
  });

  context("SHORT functions", function () {
    it("Should return totalAssets", async function () {
      const res = await (await gammaPool.totalAssets()).wait();
      console.log(res);
    });

    it("Should deposit assets to the pool", async function () {
      const res = await (await gammaPool.deposit(1000, addr1.address)).wait();
      console.log(res);
    });
  });
});
