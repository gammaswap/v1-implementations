import { ethers } from "hardhat"
import { Contract } from "ethers"
import {
  getGammaPoolDetails,
  createPair,
  createPool,
  depositReservesToPair,
  depositReserves,
  withdrawReserves,
  depositLPToken,
  withdrawLPTokens
} from './helpers'

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json")
const GammaPoolFactoryJSON = require("@gammaswap/v1-core/artifacts/contracts/GammaPoolFactory.sol/GammaPoolFactory.json")
const PositionManagerJSON = require("@gammaswap/v1-periphery/artifacts/contracts/PositionManager.sol/PositionManager.json")
const GammaPoolJSON = require("@gammaswap/v1-core/artifacts/contracts/GammaPool.sol/GammaPool.json")
const ERC20JSON = require("../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json")

const PROTOCOL_ID = 1

export async function main() {
  
  const [owner, user] = await ethers.getSigners()
  console.log(`user with address ${owner.address} logged in`);
  const UniswapV2Factory = new ethers.ContractFactory(UniswapV2FactoryJSON.abi, UniswapV2FactoryJSON.bytecode, owner)
  const GammaPoolFactory = new ethers.ContractFactory(GammaPoolFactoryJSON.abi, GammaPoolFactoryJSON.bytecode, owner)
  // const PositionManager = new ethers.ContractFactory(PositionManagerJSON.abi, PositionManagerJSON.bytecode, owner)
  const PositionManager = await ethers.getContractFactory("TestPositionManager2")
  const TestERC20Contract = await ethers.getContractFactory("TestERC20")
  const ERC20Contract = new ethers.ContractFactory(ERC20JSON.abi, ERC20JSON.bytecode, owner)
  const GammaPool = new ethers.ContractFactory(GammaPoolJSON.abi, GammaPoolJSON.bytecode, owner)
  const CPMMLongStrategy = await ethers.getContractFactory("CPMMLongStrategy")
  const CPMMShortStrategy = await ethers.getContractFactory("CPMMShortStrategy")
  const CPMMProtocol = await ethers.getContractFactory("CPMMProtocol")
  
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
  
  const cfmmFactoryAddress = uniFactory.address
  const cfmmHash = "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // uniFactory init_code_hash

  const positionManager = await PositionManager.deploy(gsFactoryAddress, WETH.address)
  positionManager.deployed()
  console.log('positionManager: ', positionManager.address)
  
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
  
  // token pair addresses
  console.log("\nCREATING PAIR ADDRESSES")
  console.log("========================")
  const token_A_B_Pair_Addr = await createPair(uniFactory, owner, tokenA, tokenB)
  const token_A_C_Pair_Addr = await createPair(uniFactory, owner, tokenA, tokenC)
  const token_B_C_Pair_Addr = await createPair(uniFactory, owner, tokenB, tokenC)
  const token_A_D_Pair_Addr = await createPair(uniFactory, owner, tokenA, tokenD)
  const token_A_WETH_Pair_Addr = await createPair(uniFactory, owner, tokenA, WETH)
  console.log("\n=========================\n")

  console.log("DEPOSITING RESERVES TO UNISWAP PAIR ADDRESSES")
  console.log("=============================================")
  const [token_A_B_Pair, AB_LPTokens] = await depositReservesToPair(token_A_B_Pair_Addr, owner, tokenA, tokenB, ethers.utils.parseEther("1"), ethers.utils.parseEther("4"))
  const [token_A_C_Pair, AC_LPTokens] = await depositReservesToPair(token_A_C_Pair_Addr, owner, tokenA, tokenC, ethers.utils.parseEther("3"), ethers.utils.parseEther("5"))
  const [token_B_C_Pair, BC_LPTokens] = await depositReservesToPair(token_B_C_Pair_Addr, owner, tokenB, tokenC, ethers.utils.parseEther("2"), ethers.utils.parseEther("6"))
  const [token_A_D_Pair, AD_LPTokens] = await depositReservesToPair(token_A_D_Pair_Addr, owner, tokenA, tokenD, ethers.utils.parseEther("4"), ethers.utils.parseEther("3"))
  const [token_A_WETH_Pair, AWETH_LPTokens] = await depositReservesToPair(token_A_WETH_Pair_Addr, owner, tokenA, WETH, ethers.utils.parseEther("5"), ethers.utils.parseEther("8"))
  console.log("=========================\n")
 
  // creating pools
  console.log("CREATING GAMMASWAP POOLS")
  console.log("=========================\n")
  const AB_GammaPool_Addr = await createPool(gsFactory, token_A_B_Pair_Addr as string, tokenA.address, tokenB.address)
  const AC_GammaPool_Addr = await createPool(gsFactory, token_A_C_Pair_Addr as string, tokenA.address, tokenC.address)
  const BC_GammaPool_Addr = await createPool(gsFactory, token_B_C_Pair_Addr as string, tokenB.address, tokenC.address)
  const AD_GammaPool_Addr = await createPool(gsFactory, token_A_D_Pair_Addr as string, tokenA.address, tokenD.address)
  const AWETH_GammaPool_Addr = await createPool(gsFactory, token_A_WETH_Pair_Addr as string, tokenA.address, WETH.address)

  const AB_GammaPool = await getGammaPoolDetails(GammaPool, AB_GammaPool_Addr)
  const AC_GammaPool = await getGammaPoolDetails(GammaPool, AC_GammaPool_Addr)
  const BC_GammaPool = await getGammaPoolDetails(GammaPool, BC_GammaPool_Addr)
  const AD_GammaPool = await getGammaPoolDetails(GammaPool, AD_GammaPool_Addr)
  const AWETH_GammaPool = await getGammaPoolDetails(GammaPool, AWETH_GammaPool_Addr)
  console.log("\n=========================\n")

  console.log("DEPOSITING/WITHDRAWING RESERVE/LP TOKENS")
  console.log("==========================================")
  await depositReserves(
    AB_GammaPool,
    positionManager,
    owner.address,
    tokenA,
    tokenB,
    [
      ethers.utils.parseEther("4"),
      ethers.utils.parseEther("2")
    ]
  )

  await withdrawReserves(
    AB_GammaPool,
    positionManager,
    owner.address,
    ethers.utils.parseEther("1.5"),
  )

  await depositLPToken(
    AB_GammaPool,
    token_A_B_Pair as Contract,
    positionManager,
    owner.address,
    ethers.utils.parseEther("1.23")
  )

  await withdrawLPTokens(
    AB_GammaPool,
    token_A_B_Pair as Contract,
    positionManager,
    owner.address,
    ethers.utils.parseEther("0.8")
  )
  console.log("\n==========================================")
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})