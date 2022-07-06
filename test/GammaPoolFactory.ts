import { ethers } from "hardhat";
import { expect } from "chai";

describe("GammaPoolFactory", function () {
  let TestERC20: any;
  let TestPoolAddress: any;
  let GammaPoolFactory: any;
  let factory: any;
  let testPoolAddress: any;
  let tokenA: any;
  let tokenB: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
    [owner, addr1, addr2] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    factory = await GammaPoolFactory.deploy(owner.address, owner.address);

    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
    await factory.deployed();
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set the right initial fields", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      expect(await factory.feeToSetter()).to.equal(owner.address);
      expect(await factory.feeTo()).to.equal(owner.address);
      expect(await tokenA.owner()).to.equal(owner.address);
      expect(await tokenB.owner()).to.equal(owner.address);

      const ownerBalanceA = await tokenA.balanceOf(owner.address);
      expect(await tokenA.totalSupply()).to.equal(ownerBalanceA);
      const ownerBalanceB = await tokenB.balanceOf(owner.address);
      expect(await tokenB.totalSupply()).to.equal(ownerBalanceB);
    });
  });

  describe("Create Pool", function () {
    it("Add Router", async function () {
      expect(await factory.getRouter(0)).to.equal(ethers.constants.AddressZero);
      expect(await factory.getRouter(1)).to.equal(ethers.constants.AddressZero);
      expect(await factory.getRouter(2)).to.equal(ethers.constants.AddressZero);
      await factory.addRouter(1, addr1.address);
      expect(await factory.getRouter(0)).to.equal(ethers.constants.AddressZero);
      expect(await factory.getRouter(1)).to.equal(addr1.address);
      expect(await factory.getRouter(2)).to.equal(ethers.constants.AddressZero);
    });

    it("Create Pool", async function () {
      await factory.addRouter(1, addr1.address);
      expect(await factory.allPoolsLength()).to.equal(0);
      await factory.createPool(tokenA.address, tokenB.address, 1);
      const poolAddressStr1: string = await factory.getPool(
        1,
        tokenA.address,
        tokenB.address
      );
      const poolAddress1 = ethers.utils.getAddress(poolAddressStr1);
      expect(poolAddress1).to.not.equal(ethers.constants.AddressZero);
      const poolAddressStr2: string = await factory.getPool(
        1,
        tokenB.address,
        tokenA.address
      );
      const poolAddress2 = ethers.utils.getAddress(poolAddressStr2);
      expect(poolAddress2).to.not.equal(ethers.constants.AddressZero);
      expect(poolAddress1).to.equal(poolAddress2);

      expect(await factory.allPoolsLength()).to.equal(1);

      const tokenC = await TestERC20.deploy("Test Token C", "TOKC");
      await factory.createPool(tokenA.address, tokenC.address, 1);

      expect(await factory.allPoolsLength()).to.equal(2);
    });

    it("Create Pool Errors", async function () {
      expect(
        factory.createPool(tokenA.address, tokenB.address, 1)
      ).to.be.revertedWith("FACTORY.createPool: PROTOCOL_NOT_SET");
      await factory.addRouter(1, addr1.address);
      expect(
        factory.createPool(tokenA.address, tokenA.address, 1)
      ).to.be.revertedWith("FACTORY.createPool: IDENTICAL_ADDRESSES");
      expect(
        factory.createPool(ethers.constants.AddressZero, tokenA.address, 1)
      ).to.be.revertedWith("FACTORY.createPool: ZERO_ADDRESS");
      expect(
        factory.createPool(tokenA.address, ethers.constants.AddressZero, 1)
      ).to.be.revertedWith("FACTORY.createPool: ZERO_ADDRESS");
      await factory.createPool(tokenA.address, tokenB.address, 1);
      expect(
        factory.createPool(tokenA.address, tokenB.address, 1)
      ).to.be.revertedWith("FACTORY.createPool: POOL_EXISTS");
    });

    it("Address is set before pool creation", async function () {
      TestPoolAddress = await ethers.getContractFactory("TestPoolAddress");
      testPoolAddress = await TestPoolAddress.deploy();
      await testPoolAddress.deployed();
      const expectedPoolAddress: string = await testPoolAddress.getPoolAddress(
        factory.address,
        tokenA.address,
        tokenB.address,
        1
      );
      await factory.addRouter(1, addr1.address);
      await factory.createPool(tokenA.address, tokenB.address, 1);
      expect(await factory.getPool(1, tokenA.address, tokenB.address)).to.equal(
        expectedPoolAddress
      );
    });
  });

  describe("Setting Fees", function () {
    it("Set Fee", async function () {
      expect(await factory.fee()).to.equal(
        ethers.BigNumber.from(5).mul(ethers.BigNumber.from(10).pow(16))
      );
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      expect(factory.connect(addr1).setFee(1)).to.be.revertedWith(
        "FACTORY.setFee: FORBIDDEN"
      );
      await factory.connect(owner).setFee(1);
      expect(await factory.fee()).to.equal(1);
    });

    it("Set Fee To", async function () {
      expect(await factory.feeTo()).to.equal(owner.address);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      expect(factory.connect(addr1).setFeeTo(addr2.address)).to.be.revertedWith(
        "FACTORY.setFeeTo: FORBIDDEN"
      );
      await factory.connect(owner).setFeeTo(addr2.address);
      expect(await factory.feeTo()).to.equal(addr2.address);
    });

    it("Set Fee To Setter", async function () {
      expect(await factory.feeToSetter()).to.equal(owner.address);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      expect(
        factory.connect(addr1).setFeeToSetter(addr2.address)
      ).to.be.revertedWith("FACTORY.setFeeToSetter: FORBIDDEN");
      await factory.connect(owner).setFeeToSetter(addr1.address);
      expect(await factory.feeToSetter()).to.equal(addr1.address);

      await factory.connect(addr1).setFeeToSetter(addr2.address);
      expect(await factory.feeToSetter()).to.equal(addr2.address);
    });
  });
});
