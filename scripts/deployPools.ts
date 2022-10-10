import { ethers } from "hardhat"
import type { TestERC20 } from "../typechain"

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json")
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json")
const GammaPoolFactoryJSON = require("@gammaswap/v1-core/artifacts/contracts/GammaPoolFactory.sol/GammaPoolFactory.json")
const GammaPoolJSON = require("@gammaswap/v1-core/artifacts/contracts/GammaPool.sol/GammaPool.json")
const PositionManagerJSON = require("@gammaswap/v1-periphery/artifacts/contracts/PositionManager.sol/PositionManager.json")

const PROTOCOL_ID = 1

export async function main() {
  
  const [owner] = await ethers.getSigners()
  console.log("owner >> ", owner.address);
  const UniswapV2Factory = new ethers.ContractFactory(UniswapV2FactoryJSON.abi, UniswapV2FactoryJSON.bytecode, owner)
  const GammaPoolFactory = new ethers.ContractFactory(GammaPoolFactoryJSON.abi, GammaPoolFactoryJSON.bytecode, owner)
  const PositionManager = new ethers.ContractFactory(PositionManagerJSON.abi, PositionManagerJSON.bytecode, owner)
  const TestERC20Contract = await ethers.getContractFactory("TestERC20")
  const GammaPool = new ethers.ContractFactory(GammaPoolJSON.abi, GammaPoolJSON.bytecode, owner)
  const CPMMLongStrategy = await ethers.getContractFactory("CPMMLongStrategy")
  const CPMMShortStrategy = await ethers.getContractFactory("CPMMShortStrategy")
  const CPMMProtocol = await ethers.getContractFactory("CPMMProtocol")
  //const PositionManager2 = await ethers.getContractFactory("TestPositionManager2")
  //const TestGammaPool = await ethers.getContractFactory("TestGammaPool")
  //const TestShortStrategy = await ethers.getContractFactory("TestShortStrategy2")

  const abi = ethers.utils.defaultAbiCoder
  const COMPUTED_INIT_CODE_HASH = ethers.utils.keccak256(GammaPool.bytecode)
  console.log('COMPUTED_INIT_CODE_HASH: ', COMPUTED_INIT_CODE_HASH);

  const uniFactory = await UniswapV2Factory.deploy(owner.address)
  const gsFactory = await GammaPoolFactory.deploy(owner.address)
  const longStrategy = await CPMMLongStrategy.deploy()
  const shortStrategy = await CPMMShortStrategy.deploy()
  const tokenA = await TestERC20Contract.deploy("Token A", "TOKA")
  const tokenB = await TestERC20Contract.deploy("Token B", "TOKB")
  const tokenC = await TestERC20Contract.deploy("Token C", "TOKC")
  const tokenD = await TestERC20Contract.deploy("Token D", "TOKD")
  const WETH = await TestERC20Contract.deploy("WETH", "WETH")
  console.log("WETH.address >> ", WETH.address)
  console.log("tokenA.address >> ", tokenA.address)
  console.log("tokenB.address >> ", tokenB.address)

  await uniFactory.deployed()
  await gsFactory.deployed()
  await longStrategy.deployed()
  await shortStrategy.deployed()
  await tokenA.deployed()
  await tokenB.deployed()
  await tokenC.deployed()
  await tokenD.deployed()
  await WETH.deployed()

  const gsFactoryAddress = gsFactory.address
  console.log('gsFactoryAddress: ', gsFactoryAddress);

  const posMgr = await PositionManager.deploy(gsFactoryAddress, WETH.address)
  console.log('posManagerAddress: ', posMgr.address)

  const cfmmFactoryAddress = uniFactory.address
  const cfmmHash = "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // uniFactory init_code_hash

  const protocolParams = abi.encode(
    [
      "address",
      "bytes32",
      "uint16",
      "uint16",
      "uint256",
      "uint256",
      "uint256",
      "uint256"
    ],
    [
      cfmmFactoryAddress,
      cfmmHash,
      1000,
      997,
      ethers.utils.parseUnits("1.0", 16),
      ethers.utils.parseUnits("8.0", 17),
      ethers.utils.parseUnits("4.0", 16),
      ethers.utils.parseUnits("75.0", 16)
    ]
  )
  const protocol = await CPMMProtocol.deploy(
    gsFactoryAddress,
    PROTOCOL_ID,
    protocolParams,
    longStrategy.address,
    shortStrategy.address,
  )
  await protocol.deployed()
  const CPMMProtocolAddress = protocol.address

  await gsFactory.addProtocol(CPMMProtocolAddress)

  function getGammaPoolKey(cfmmPair: string, protocol: number) {
    const encoded = abi.encode(["address", "uint24"], [cfmmPair, protocol])
    return ethers.utils.keccak256(encoded)
  }

  function calcGammaPoolAddress(factory: string, key: string, initCodeHash: string) {
    const hexLiteral = "0xff"
    const encoded = ethers.utils.solidityPack(["address", "address", "bytes32", "bytes32"], [hexLiteral, factory, key, initCodeHash])
    const hashed = ethers.utils.keccak256(encoded)

    const poolAddressInputs = [hexLiteral, factory, hashed, initCodeHash]

    const builtAddress = `0x${poolAddressInputs.map(i => i.slice(2)).join('')}`
    return ethers.utils.getAddress(`0x${ethers.utils.keccak256(builtAddress).slice(-40)}`)
  }

  async function createPair(token1: TestERC20, token2: TestERC20) {
    await uniFactory.createPair(token1.address, token2.address)
    const cfmmPairAddress: string = await uniFactory.getPair(token1.address, token2.address)

    const token1Symbol = await token1.symbol()
    const token2Symbol = await token2.symbol()
    console.log(`${token1Symbol}/${token2Symbol} Pair Address: ${cfmmPairAddress}`)

    // initial reserves
    const pair = new ethers.Contract(cfmmPairAddress, UniswapV2PairJSON.abi, owner)
    let amountToTransfer = ethers.utils.parseEther("100")
    await token1.transfer(cfmmPairAddress, amountToTransfer)
    await token2.transfer(cfmmPairAddress, amountToTransfer)
    await pair.mint(owner.address)

    return cfmmPairAddress
  }

  // token pair addresses
  const token_A_B_Pair = await createPair(tokenA, tokenB)
  const token_A_C_Pair = await createPair(tokenA, tokenC)
  const token_B_C_Pair = await createPair(tokenB, tokenC)
  const token_A_D_Pair = await createPair(tokenA, tokenD)
  const token_A_WETH_Pair = await createPair(tokenA, WETH)

  const createPool = async (cfmmPair: string, token1: string, token2: string) => {
    const CreatePoolParams = {
      cfmm: cfmmPair,
      protocol: PROTOCOL_ID,
      tokens: [token1, token2]
    }
    
    try {
      const res = await (await gsFactory.createPool(CreatePoolParams, { gasLimit: 10000000 })).wait()

      if (res?.events && res?.events[0]?.args) {
        const key = getGammaPoolKey(cfmmPair, PROTOCOL_ID)
        const pool = await gsFactory.getPool(key)

        const gammaPool = GammaPool.attach(pool)
        const poolSymbol = await gammaPool.symbol()
        console.log(`${poolSymbol} Address: ${pool}`)
        return gammaPool;
      } else {
        console.log(`PoolEventsError: no events fired for ${cfmmPair}\n`)
      }
    } catch (e) {
      console.log(`Could not deploy GammaPool of address ${cfmmPair}\n`)
      console.log(`PoolCreationError: ${e}`)
    }
  }

  const pool1 = await createPool(token_A_B_Pair as string, tokenA.address, tokenB.address)
  const pool2 = await createPool(token_A_C_Pair as string, tokenA.address, tokenC.address)
  const pool3 = await createPool(token_B_C_Pair as string, tokenB.address, tokenC.address)
  const pool4 = await createPool(token_A_D_Pair as string, tokenA.address, tokenD.address)
  const pool5 = await createPool(token_A_WETH_Pair as string, tokenA.address, WETH.address)

  //const testGammaPool = await TestGammaPool.deploy();
  //console.log("testGammaPool >> ", testGammaPool.address);
  //const testShortStrategy = await TestShortStrategy.deploy()

  //const posMgr2 = await PositionManager2.deploy(testGammaPool.address, testShortStrategy.address, gsFactoryAddress, WETH.address);
  //console.log('posManagerAddress2: ', posMgr2.address)

  await (await tokenA.approve(posMgr.address, ethers.constants.MaxUint256)).wait();
  await (await tokenB.approve(posMgr.address, ethers.constants.MaxUint256)).wait();

  //const cfmmX = await pool1.cfmm();
  //console.log("cfmmX >> ", cfmmX);
  // mine 256 blocks
  await ethers.provider.send("hardhat_mine", ["0x100"]);

  let amt = ethers.utils.parseEther("1")

  const DepositReservesParams = {
    cfmm: token_A_B_Pair,
    amountsDesired: [amt, amt],
    amountsMin: [0, 0],
    to: owner.address,
    protocol: PROTOCOL_ID,
    deadline: ethers.constants.MaxUint256
  }
  //const res = await (await posMgr2.depositReserves(DepositReservesParams)).wait();
  const res = await (await posMgr.depositReserves(DepositReservesParams)).wait();
  //console.log("res >>")
  //console.log(res)/**/

  const bal = await pool1.balanceOf(owner.address);
  console.log("bal >> ", bal);

  await (await pool1.approve(posMgr.address, ethers.constants.MaxUint256)).wait();

  const WithdrawReservesParams = {
    cfmm: token_A_B_Pair,
    protocol: PROTOCOL_ID,
    amount: amt.div(2),
    amountsMin: [0, 0],
    to: owner.address,
    deadline: ethers.constants.MaxUint256
  }
  const res1 = await (await posMgr.withdrawReserves(WithdrawReservesParams)).wait();
  //console.log("res1 >>")
  //console.log(res1)/**/

  const bal2 = await pool1.balanceOf(owner.address);
  console.log("bal2 >> ", bal2);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})