import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

const PROTOCOL_ID = 1;

describe("CPMMProtocol", function () {
  let TestERC20: any;
  let CPMMProtocol: any;
  let UniswapV2Factory: any;
  let UniswapV2Pair: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let protocol: any;
  let gsFactoryAddress: any;
  let cfmmHash: any;
  let longStrategyAddr: any;
  let shortStrategyAddr: any;
  let cfmm: any;
  let uniFactory: any;
  let badProtocol: any;
  let badProtocol2: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    CPMMProtocol = await ethers.getContractFactory("CPMMProtocol");
    [owner, addr1, addr2] = await ethers.getSigners();
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

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");

    uniFactory = await UniswapV2Factory.deploy(owner.address);

    cfmm = await createPair(tokenA, tokenB);

    gsFactoryAddress = owner.address;
    cfmmHash =
      "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f";
    longStrategyAddr = addr1.address;
    shortStrategyAddr = addr2.address;

    protocol = await CPMMProtocol.deploy(
      PROTOCOL_ID,
      longStrategyAddr,
      shortStrategyAddr,
      uniFactory.address,
      cfmmHash
    );

    const badCfmmHash =
      "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845e";

    badProtocol = await CPMMProtocol.deploy(
      PROTOCOL_ID,
      longStrategyAddr,
      shortStrategyAddr,
      uniFactory.address,
      badCfmmHash
    );

    badProtocol2 = await CPMMProtocol.deploy(
      PROTOCOL_ID,
      longStrategyAddr,
      shortStrategyAddr,
      gsFactoryAddress,
      cfmmHash
    );
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

  async function validateCFMM(token0: any, token1: any, cfmm: any) {
    const tokens = await protocol.validateCFMM(
      [token0.address, token1.address],
      cfmm.address
    );
    const bigNum0 = BigNumber.from(token0.address);
    const bigNum1 = BigNumber.from(token1.address);
    const token0Addr = bigNum0.lt(bigNum1) ? token0.address : token1.address;
    const token1Addr = bigNum0.lt(bigNum1) ? token1.address : token0.address;
    expect(tokens[0]).to.equal(token0Addr);
    expect(tokens[1]).to.equal(token1Addr);
  }

  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await protocol.protocolId()).to.equal(1);
      expect(await protocol.longStrategy()).to.equal(addr1.address);
      expect(await protocol.shortStrategy()).to.equal(addr2.address);
      expect(await protocol.factory()).to.equal(uniFactory.address);
      expect(await protocol.initCodeHash()).to.equal(cfmmHash);
    });
  });

  describe("Validate CFMM", function () {
    it("Error is Not Contract", async function () {
      await expect(
        protocol.validateCFMM([tokenA.address, tokenB.address], owner.address)
      ).to.be.revertedWith("NotContract");
    });

    it("Error Not Right Contract", async function () {
      await expect(
        protocol.validateCFMM(
          [tokenA.address, tokenB.address],
          uniFactory.address
        )
      ).to.be.revertedWith("BadProtocol");
    });

    it("Error Not Right Tokens", async function () {
      await expect(
        protocol.validateCFMM([tokenA.address, tokenC.address], cfmm.address)
      ).to.be.revertedWith("BadProtocol");
    });

    it("Error Bad Hash", async function () {
      expect(await badProtocol.factory()).to.equal(uniFactory.address);
      expect(await badProtocol.initCodeHash()).to.not.equal(cfmmHash);
      await expect(
        badProtocol.validateCFMM([tokenA.address, tokenB.address], cfmm.address)
      ).to.be.revertedWith("BadProtocol");
    });

    it("Error Bad Factory", async function () {
      expect(await badProtocol2.factory()).to.not.equal(uniFactory.address);
      expect(await badProtocol2.initCodeHash()).to.equal(cfmmHash);
      await expect(
        badProtocol2.validateCFMM(
          [tokenA.address, tokenB.address],
          cfmm.address
        )
      ).to.be.revertedWith("BadProtocol");
    });

    it("Correct Validation", async function () {
      expect(await protocol.factory()).to.equal(uniFactory.address);
      expect(await protocol.initCodeHash()).to.equal(cfmmHash);

      await validateCFMM(tokenA, tokenB, cfmm);

      const cfmm1 = await createPair(tokenA, tokenC);
      await validateCFMM(tokenA, tokenC, cfmm1);

      const cfmm2 = await createPair(tokenB, tokenC);
      await validateCFMM(tokenB, tokenC, cfmm2);
    });
  });
});
