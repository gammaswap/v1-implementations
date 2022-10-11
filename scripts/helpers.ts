import { ethers } from "hardhat"
import { Contract, ContractFactory, BigNumber } from "ethers"
import type { TestERC20 } from "../typechain"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json")

const PROTOCOL_ID = 1
const AMOUNTS_MIN = [0, 0]

const overrides = {
  gasLimit: 30000000
}

const convertToETH = (value: BigNumber): string => {
  return ethers.utils.formatEther(value.toString())
}

const abi = ethers.utils.defaultAbiCoder

const getGammaPoolKey = (cfmmPair: string, protocol: number) => {
  const encoded = abi.encode(["address", "uint24"], [cfmmPair, protocol])
  return ethers.utils.keccak256(encoded)
}

export const calcGammaPoolAddress = (factory: string, key: string, initCodeHash: string) => {
  const hexLiteral = "0xff"
  const encoded = ethers.utils.solidityPack(["address", "address", "bytes32", "bytes32"], [hexLiteral, factory, key, initCodeHash])
  const hashed = ethers.utils.keccak256(encoded)

  const poolAddressInputs = [hexLiteral, factory, hashed, initCodeHash]

  const builtAddress = `0x${poolAddressInputs.map(i => i.slice(2)).join('')}`
  return ethers.utils.getAddress(`0x${ethers.utils.keccak256(builtAddress).slice(-40)}`)
}

export const getGammaPoolDetails = async (GammaPool: ContractFactory, gammaPoolAddress: string) => {
  const gammaPool = GammaPool.attach(gammaPoolAddress)
  const gammaPoolSymbol = await gammaPool.symbol()
  console.log(`${gammaPoolSymbol} Pool: ${gammaPoolAddress}`)
  return gammaPool
}

export const createPair = async (uniswapV2Factory: Contract, owner: SignerWithAddress, token0: TestERC20, token1: TestERC20) => {
  await uniswapV2Factory.createPair(token0.address, token1.address)
  const cfmmPairAddress: string = await uniswapV2Factory.getPair(token0.address, token1.address)
  
  const token0Symbol = await token0.symbol()
  const token1Symbol = await token1.symbol()
  console.log(`${token0Symbol}/${token1Symbol} Pair Address: ${cfmmPairAddress}`)
  
  // initial reserves
  const pair = new ethers.Contract(cfmmPairAddress, UniswapV2PairJSON.abi, owner)
  let amountToTransfer = ethers.utils.parseEther("100")
  await token0.transfer(cfmmPairAddress, amountToTransfer)
  await token1.transfer(cfmmPairAddress, amountToTransfer)
  await pair.mint(owner.address)

  return cfmmPairAddress
}

export const createPool = async (gsFactory: Contract, cfmmPair: string, token1: string, token2: string) => {
  const CreatePoolParams = {
    cfmm: cfmmPair,
    protocol: PROTOCOL_ID,
    tokens: [token1, token2]
  }
  
  try {
    const res = await (await gsFactory.createPool(CreatePoolParams, overrides)).wait()

    if (res?.events && res?.events[0]?.args) {
      const key = getGammaPoolKey(cfmmPair, PROTOCOL_ID)
      const pool = await gsFactory.getPool(key)

      return pool
    }
  } catch (e) {
    console.log(`Could not deploy GammaPool of address ${cfmmPair}\n`)
    console.log(`PoolCreationError: ${e}`)
  }
}


const checkDepositReservesToPair = async (pair: Contract, userAddress: string): Promise<BigNumber> => {
  const newTotalSupply = await pair.totalSupply()
  const sharesReceived = await pair.balanceOf(userAddress)

  console.log(`${pair.address} pair NEW total supply is ${convertToETH(newTotalSupply)}`)
  console.log(`user ${userAddress} received ${convertToETH(sharesReceived)} in LP tokens\n`)
  return sharesReceived
}

export const depositReservesToPair = async (
  pairAddress: string,
  owner: SignerWithAddress,
  token0Contract: TestERC20,
  token1Contract: TestERC20,
  token0Amt: BigNumber,
  token1Amt: BigNumber
): Promise<(Contract | BigNumber)[]> => {
  console.log(`\ndepositing ${convertToETH(token0Amt)} and ${convertToETH(token1Amt)} into pair ${pairAddress}...`)
  const pair = new ethers.Contract(pairAddress, UniswapV2PairJSON.abi, owner)
  const originalTotalSupply = await pair.totalSupply()
  console.log(`${pairAddress} pair total supply is ${convertToETH(originalTotalSupply)}`)
  const pairToken0Address = await pair.token0()

  const token0 = token0Contract.address === pairToken0Address ? token0Contract : token1Contract
  const token1 = token0Contract.address === pairToken0Address ? token1Contract : token0Contract

  await token0.transfer(pair.address, token0Amt)
  await token1.transfer(pair.address, token1Amt)

  await pair.mint(owner.address, overrides)
  const lpTokens = await checkDepositReservesToPair(pair, owner.address)
  return [pair, lpTokens]
}


export const depositReserves = async (
  gammaPool: Contract,
  positionManager: Contract,
  userAddress: string,
  token0: TestERC20,
  token1: TestERC20,
  amountsDesired: BigNumber[]
) => {
  const pairAddress = await gammaPool.cfmm()
  const protocolId = await gammaPool.protocolId()

  const DepositReservesParams = {
    cfmm: pairAddress,
    amountsDesired: amountsDesired,
    amountsMin: AMOUNTS_MIN,
    to: userAddress,
    protocol: protocolId,
    deadline: ethers.constants.MaxUint256
  }
  console.log(`\ndepositing ${convertToETH(amountsDesired[0])} and ${convertToETH(amountsDesired[1])} into pool ${gammaPool.address}...`)
  const prevUserBalance = await gammaPool.balanceOf(userAddress)
  console.log(`current balance: ${convertToETH(prevUserBalance)} ADD RESERVE`)

  // tokens are allowing positionManager to interact with it
  await (await token0.approve(positionManager.address, ethers.constants.MaxUint256)).wait()
  await (await token1.approve(positionManager.address, ethers.constants.MaxUint256)).wait()

  // advance 256 blocks
  // await ethers.provider.send("hardhat_mine", ["0x100"])
  
  const res = await (await positionManager.depositReserves(DepositReservesParams, overrides)).wait()
  if (res?.events && res?.events[res?.events.length - 1]?.args) {
    const eventsLength = res?.events.length
    const eventArgs = res?.events[eventsLength - 1].args

    const gammaPoolSymbol = await gammaPool.symbol()
    const reservesLength = eventArgs.reservesLen
    const lpTokensReceived = eventArgs.shares

    // the user's balance inside the gammaPool
    const userBalance = await gammaPool.balanceOf(userAddress)
    console.log(`you, ${userAddress}, now have ${convertToETH(userBalance)} of ${gammaPoolSymbol} LP tokens`)
  } else {
    console.log(`DepositReservesEventError: could not fire events`)
  }
}

export const withdrawReserves = async (
  gammaPool: Contract,
  positionManager: Contract,
  userAddress: string,
  amountToWithdraw: BigNumber
) => {
  const pairAddress = await gammaPool.cfmm()
  const protocolId = await gammaPool.protocolId()

  const WithdrawReservesParams = {
    cfmm: pairAddress,
    amount: amountToWithdraw,
    amountsMin: AMOUNTS_MIN,
    to: userAddress,
    protocol: protocolId,
    deadline: ethers.constants.MaxUint256
  }
  console.log(`\nwithdrawing ${convertToETH(amountToWithdraw)} from pool ${gammaPool.address}...`)
  const prevUserBalance = await gammaPool.balanceOf(userAddress)
  console.log(`current balance: ${convertToETH(prevUserBalance)} WITHDRAW RESERVE`)
  
  // gammaPool is allowing positionManager to interact with it
  await (await gammaPool.approve(positionManager.address, ethers.constants.MaxUint256)).wait()

  const res = await (await positionManager.withdrawReserves(WithdrawReservesParams, overrides)).wait()
  if (res?.events && res?.events[res?.events.length - 1]?.args) {
    const eventsLength = res?.events.length
    const eventArgs = res?.events[eventsLength - 1].args

    const gammaPoolSymbol = await gammaPool.symbol()
    const reservesLength = eventArgs.reservesLen
    const assetsRemoved = eventArgs.assets

    // the user's balance inside the gammaPool
    const userBalance = await gammaPool.balanceOf(userAddress)
    console.log(`you, ${userAddress}, now have ${convertToETH(userBalance)} of ${gammaPoolSymbol} LP tokens`)
  } else {
    console.log(`WithdrawReservesEventError: could not fire events`)
  }
}

export const depositLPToken = async (
  gammaPool: Contract,
  positionManager: Contract,
  userAddress: string,
  token0: TestERC20,
  token1: TestERC20,
  amount: BigNumber
) => {
  const gammaPoolAddress = gammaPool.address
  const gammaPoolTokens = await gammaPool.lpTokenBalance()
  console.log('gammaPoolTokens: ', convertToETH(gammaPoolTokens))
  const gammaPoolSymbol = await gammaPool.symbol()
  const protocolId = await gammaPool.protocolId()
  const cfmmPairAddr = await gammaPool.cfmm()

  await token0.approve(positionManager.address, ethers.constants.MaxUint256)
  await token1.approve(positionManager.address, ethers.constants.MaxUint256)

  const depositNoPullParams = {
    cfmm: cfmmPairAddr,
    protocol: protocolId,
    lpTokens: amount,
    to: userAddress,
    deadline: ethers.constants.MaxUint256
  }
  console.log(`depositing ${convertToETH(amount)} LP tokens into ${gammaPoolSymbol} pool...`)
  const prevUserBalance = await gammaPool.balanceOf(userAddress)
  console.log(`current balance: ${convertToETH(prevUserBalance)} DEPOSIT LP TOKEN`)

  try {
    const res = await (await positionManager.depositNoPull(depositNoPullParams, overrides)).wait()
    if (res?.events && res?.events[res?.events.length - 1]?.args) {
      const eventsLength = res?.events.length
      const eventArgs = res?.events[eventsLength - 1]?.args
      console.log('eventArgs: ', eventArgs);

      // the user's balance inside the gammaPool
      const userBalance = await gammaPool.balanceOf(userAddress)
      console.log(`you, ${userAddress}, now have ${convertToETH(userBalance)} of ${gammaPoolSymbol} LP tokens`)
    } else {
      console.log(`DepositNoPullEventError: could not fire events for gammaPool of ${gammaPoolAddress}`)
    }
  } catch (e) {
    console.log(`DepositLPTokenError: 
    user ${userAddress} could not deposit ${convertToETH(amount)} into gammaPool ${gammaPoolAddress}`)
    console.error(e)
  }
}


