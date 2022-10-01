import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

const PROTOCOL_ID = 1;

describe.only("CPMMProtocol", function () {
  let TestERC20: any;
  let TestCPMMProtocol: any;
  let TestCPMMProtocol2: any;
  let UniswapV2Factory: any;
  let UniswapV2Pair: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let protocol: any;
  let protocol2: any;
  let gsFactoryAddress: any;
  let cfmmHash: any;
  let longStrategyAddr: any;
  let shortStrategyAddr: any;
  let tradingFee1: any;
  let tradingFee2: any;
  let baseRate: any;
  let optimalUtilRate: any;
  let slope1: any;
  let slope2: any;
  let ONE: any;
  let cfmm: any;
  let uniFactory: any;
  let badProtocol: any;
  let badProtocol2: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCPMMProtocol = await ethers.getContractFactory("TestCPMMProtocol");
    TestCPMMProtocol2 = await ethers.getContractFactory("TestCPMMProtocol2");
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

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");

    uniFactory = await UniswapV2Factory.deploy(owner.address);

    cfmm = await createPair(tokenA, tokenB);

    ONE = BigNumber.from(10).pow(18);
    gsFactoryAddress = owner.address;
    cfmmHash =
      "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f";
    longStrategyAddr = addr1.address;
    shortStrategyAddr = addr2.address;
    tradingFee1 = BigNumber.from(1000);
    tradingFee2 = BigNumber.from(997);
    baseRate = ONE.div(100);
    optimalUtilRate = ONE.mul(8).div(10);
    slope1 = ONE.mul(4).div(100);
    slope2 = ONE.mul(75).div(100);
    const abi = ethers.utils.defaultAbiCoder;
    const params = abi.encode(
      [
        "address",
        "bytes32",
        "uint16",
        "uint16",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
      ],
      [
        uniFactory.address,
        cfmmHash,
        tradingFee1,
        tradingFee2,
        baseRate,
        optimalUtilRate,
        slope1,
        slope2,
      ]
    );

    protocol = await TestCPMMProtocol.deploy(
      gsFactoryAddress,
      PROTOCOL_ID,
      params,
      longStrategyAddr,
      shortStrategyAddr
    );

    protocol2 = await TestCPMMProtocol2.deploy(protocol.address);

    const badCfmmHash =
      "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845e";
    const badParams = abi.encode(
      [
        "address",
        "bytes32",
        "uint16",
        "uint16",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
      ],
      [
        uniFactory.address,
        badCfmmHash,
        tradingFee1,
        tradingFee2,
        baseRate,
        optimalUtilRate,
        slope1,
        slope2,
      ]
    );

    badProtocol = await TestCPMMProtocol.deploy(
      gsFactoryAddress,
      PROTOCOL_ID,
      badParams,
      longStrategyAddr,
      shortStrategyAddr
    );

    const badParams2 = abi.encode(
      [
        "address",
        "bytes32",
        "uint16",
        "uint16",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
      ],
      [
        gsFactoryAddress,
        cfmmHash,
        tradingFee1,
        tradingFee2,
        baseRate,
        optimalUtilRate,
        slope1,
        slope2,
      ]
    );

    badProtocol2 = await TestCPMMProtocol.deploy(
      gsFactoryAddress,
      PROTOCOL_ID,
      badParams2,
      longStrategyAddr,
      shortStrategyAddr
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
    const token0Addr =
      token0.address < token1.address ? token0.address : token1.address;
    const token1Addr =
      token0.address < token1.address ? token1.address : token0.address;
    expect(tokens[0]).to.equal(token0Addr);
    expect(tokens[1]).to.equal(token1Addr);
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await protocol._owner()).to.equal(gsFactoryAddress);
      expect(await protocol.protocol()).to.equal(1);
      expect(await protocol.longStrategy()).to.equal(addr1.address);
      expect(await protocol.shortStrategy()).to.equal(addr2.address);
      expect(await protocol.owner()).to.equal(gsFactoryAddress);
      expect(await protocol.isSet()).to.equal(true);
      expect(await protocol.factory()).to.equal(uniFactory.address);
      expect(await protocol.initCodeHash()).to.equal(cfmmHash);
      expect(await protocol.tradingFee1()).to.equal(tradingFee1);
      expect(await protocol.tradingFee2()).to.equal(tradingFee2);
      expect(await protocol.baseRate()).to.equal(baseRate);
      expect(await protocol.optimalUtilRate()).to.equal(optimalUtilRate);
      expect(await protocol.slope1()).to.equal(slope1);
      expect(await protocol.slope2()).to.equal(slope2);
    });

    it("Get Strategy Parameters", async function () {
      const params = await protocol.testStrategyParams();
      const sParams = ethers.utils.hexlify(params);
      const _sParams = ethers.utils.defaultAbiCoder.decode(
        ["address", "bytes32", "uint16", "uint16", "bool"], // specify your return type/s here
        ethers.utils.hexDataSlice(sParams, 0)
      );
      expect(_sParams[0]).to.equal(uniFactory.address);
      expect(_sParams[1]).to.equal(cfmmHash);
      expect(_sParams[2]).to.equal(tradingFee1);
      expect(_sParams[3]).to.equal(tradingFee2);
      expect(_sParams[4]).to.equal(false);
    });

    it("Get Rate Parameters", async function () {
      const params = await protocol.testRateParams();
      const rParams = ethers.utils.hexlify(params);
      const _rParams = ethers.utils.defaultAbiCoder.decode(
        [
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "bool",
        ], // specify your return type/s here
        ethers.utils.hexDataSlice(rParams, 0)
      );
      expect(_rParams[0]).to.equal(ONE);
      expect(_rParams[1]).to.equal(2252571);
      expect(_rParams[2]).to.equal(baseRate);
      expect(_rParams[3]).to.equal(optimalUtilRate);
      expect(_rParams[4]).to.equal(slope1);
      expect(_rParams[5]).to.equal(slope2);
      expect(_rParams[6]).to.equal(false);
    });
  });

  describe("Initialize Params", function () {
    it("Error Initialize Strategy Params", async function () {
      const newFactoryAddress = addr3.address;
      const newTradingFee1 = 99;
      const newTradingFee2 = 88;
      const newCfmmHash =
        "0x0000000000000000000085478aa9a39f403cb768dd02cbee326c3e7da348845f";
      const newParams = ethers.utils.defaultAbiCoder.encode(
        ["address", "bytes32", "uint16", "uint16", "bool"],
        [newFactoryAddress, newCfmmHash, newTradingFee1, newTradingFee2, true]
      );
      await expect(
        protocol.testInitializeStrategyParams(newParams)
      ).to.be.revertedWith("SET");
    });

    it("Initialize Strategy Params", async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const newFactoryAddress = addr3.address;
      const newCfmmHash =
        "0x0000000000000000000085478aa9a39f403cb768dd02cbee326c3e7da348845f";
      const newTradingFee1 = 99;
      const newTradingFee2 = 88;
      const newParams = abi.encode(
        ["address", "bytes32", "uint16", "uint16", "bool"],
        [newFactoryAddress, newCfmmHash, newTradingFee1, newTradingFee2, true]
      );
      await (await protocol2.testInitializeStrategyParams(newParams)).wait();

      const params = await protocol2.getStrategyParams();
      const sParams = ethers.utils.hexlify(params);
      const _sParams = ethers.utils.defaultAbiCoder.decode(
        ["address", "bytes32", "uint16", "uint16", "bool"], // specify your return type/s here
        ethers.utils.hexDataSlice(sParams, 0)
      );
      expect(_sParams[0]).to.not.equal(uniFactory.address);
      expect(_sParams[1]).to.not.equal(cfmmHash);
      expect(_sParams[2]).to.not.equal(tradingFee1);
      expect(_sParams[3]).to.not.equal(tradingFee2);
      expect(_sParams[4]).to.not.equal(false);
      expect(_sParams[0]).to.equal(newFactoryAddress);
      expect(_sParams[1]).to.equal(newCfmmHash);
      expect(_sParams[2]).to.equal(newTradingFee1);
      expect(_sParams[3]).to.equal(newTradingFee2);
      expect(_sParams[4]).to.equal(true);
    });

    it("Error Initialize Rate Params", async function () {
      const newBaseRate = ONE.mul(2);
      const newOptimalUtilRate = ONE.mul(3);
      const newSlope1 = ONE.mul(4);
      const newSlope2 = ONE.mul(5);
      const newParams = ethers.utils.defaultAbiCoder.encode(
        [
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "bool",
        ], // specify your return type/s here
        [
          ONE.mul(6),
          1111111,
          newBaseRate,
          newOptimalUtilRate,
          newSlope1,
          newSlope2,
          true,
        ]
      );

      await expect(
        protocol.testInitializeRateParams(newParams)
      ).to.be.revertedWith("SET");
    });

    it("Initialize Rate Params", async function () {
      const newBaseRate = ONE.mul(2);
      const newOptimalUtilRate = ONE.mul(3);
      const newSlope1 = ONE.mul(4);
      const newSlope2 = ONE.mul(5);
      const newParams = ethers.utils.defaultAbiCoder.encode(
        [
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "bool",
        ], // specify your return type/s here
        [
          ONE.mul(6),
          1111111,
          newBaseRate,
          newOptimalUtilRate,
          newSlope1,
          newSlope2,
          true,
        ]
      );

      await (await protocol2.testInitializeRateParams(newParams)).wait();

      const params = await protocol2.getRateParams();
      const rParams = ethers.utils.hexlify(params);
      const _rParams = ethers.utils.defaultAbiCoder.decode(
        [
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "uint256",
          "bool",
        ], // specify your return type/s here
        ethers.utils.hexDataSlice(rParams, 0)
      );
      expect(_rParams[0]).to.not.equal(ONE.mul(6));
      expect(_rParams[1]).to.not.equal(1111111);
      expect(_rParams[2]).to.not.equal(baseRate);
      expect(_rParams[3]).to.not.equal(optimalUtilRate);
      expect(_rParams[4]).to.not.equal(slope1);
      expect(_rParams[5]).to.not.equal(slope2);
      expect(_rParams[6]).to.not.equal(false);
      expect(_rParams[0]).to.equal(ONE);
      expect(_rParams[1]).to.equal(2252571);
      expect(_rParams[2]).to.equal(newBaseRate);
      expect(_rParams[3]).to.equal(newOptimalUtilRate);
      expect(_rParams[4]).to.equal(newSlope1);
      expect(_rParams[5]).to.equal(newSlope2);
      expect(_rParams[6]).to.equal(true);
    });
  });

  describe("Validate CFMM", function () {
    it("Error is Not Contract", async function () {
      await expect(
        protocol.validateCFMM([tokenA.address, tokenB.address], owner.address)
      ).to.be.revertedWith("not contract");
    });

    it("Error Not Right Contract", async function () {
      await expect(
        protocol.validateCFMM(
          [tokenA.address, tokenB.address],
          protocol2.address
        )
      ).to.be.revertedWith("bad protocol");
    });

    it("Error Not Right Tokens", async function () {
      await expect(
        protocol.validateCFMM([tokenA.address, tokenC.address], cfmm.address)
      ).to.be.revertedWith("bad protocol");
    });

    it("Error Bad Hash", async function () {
      expect(await badProtocol.factory()).to.equal(uniFactory.address);
      expect(await badProtocol.initCodeHash()).to.not.equal(cfmmHash);
      await expect(
        badProtocol.validateCFMM([tokenA.address, tokenB.address], cfmm.address)
      ).to.be.revertedWith("bad protocol");
    });

    it("Error Bad Factory", async function () {
      expect(await badProtocol2.factory()).to.not.equal(uniFactory.address);
      expect(await badProtocol2.initCodeHash()).to.equal(cfmmHash);
      await expect(
        badProtocol2.validateCFMM(
          [tokenA.address, tokenB.address],
          cfmm.address
        )
      ).to.be.revertedWith("bad protocol");
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
