import { ethers } from 'hardhat'
import { expect } from 'chai'

// constants
const UNISWAPV2_PROTOCOL = 1
const NULL_PROTOCOL = 0

describe("GammaPool Contract", async function () {
  let MockERC20
  let MockPoolAddress
  let MockProtocol
  let GammaPool
  let GammaPoolFactory
  let gammaPool: any
  let owner: any
  let addr1
  let addr2
  let addr3
  let tokenA: any
  let tokenB: any
  let mockPoolAddress: any
  let cfmm
  let protocol
  let nullProtocol
  // get ContractFactory and signers
  // NOTE: there are some functions missing from typechain that we need like bytecode()
  // and deploy(). will stick without type-safe for now.

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners()
    MockERC20 = await ethers.getContractFactory("TestERC20")
    MockPoolAddress = await ethers.getContractFactory("TestPoolAddress")
    MockProtocol = await ethers.getContractFactory("TestProtocol")
    GammaPool = await ethers.getContractFactory("GammaPool")
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory")

    // contract deployment
    tokenA = await MockERC20.deploy("Test Token A", "TOKA")
    tokenB = await MockERC20.deploy("Test Token B", "TOKB")
    mockPoolAddress = await MockPoolAddress.deploy()
    cfmm = await MockERC20.deploy("CFMM LP Token", "LP_CFMM")
    protocol = await MockProtocol.deploy(addr1.address, addr2.address, UNISWAPV2_PROTOCOL)
    nullProtocol = await MockProtocol.deploy(addr1.address, addr2.address, NULL_PROTOCOL)

    const factory = await GammaPoolFactory.deploy(owner.address)

    // allows interaction with smart contract methods
    await tokenA.deployed()
    await tokenB.deployed()
    await mockPoolAddress.deployed()
    await cfmm.deployed()
    await protocol.deployed()
    await nullProtocol.deployed()
    await factory.deployed()

    await factory.addProtocol(protocol.address)

    const createPoolParams = {
      cfmm: cfmm.address,
      protocol: UNISWAPV2_PROTOCOL,
      tokens: [tokenA.address, tokenB.address]
    }

    const poolCreated = await (await factory.createPool(createPoolParams)).wait()
    if (poolCreated.events) {
      console.log('poolCreated.events: ', poolCreated.events);
      const { args } = poolCreated.events[1]
      // deployed pool contract address
      const gammaPoolAddr = args?.pool
      gammaPool = GammaPool.attach(gammaPoolAddr)
    }
  })

  describe("Deployment", function () {

    // expects the owner variable stored in the contract equals our Signer's owner
    it("Should set the right owner", async function () {
      const tokenAOwner = await tokenA.owner()
      const tokenBOwner = await tokenB.owner()

      expect(tokenAOwner).to.equal(owner.address)
      expect(tokenBOwner).to.equal(owner.address)
    })

    // expects that the created pool ICH matches the mock pool ICH
    it("Should be right INIT_CODE_HASH", async function () {
      const COMPUTED_INIT_CODE_HASH = ethers
      .utils
      .keccak256(gammaPool.bytecode)
      const MOCK_POOL_INIT_CODE_HASH = await mockPoolAddress.getInitCodeHash()

      expect(COMPUTED_INIT_CODE_HASH).to.equal(MOCK_POOL_INIT_CODE_HASH)
    })

    // expects that the correct owner deployed the tokens
    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await tokenA.balanceOf(owner.address)
      const tokenASupply = await tokenA.totalSupply()
      const tokenBSupply = await tokenB.totalSupply()

      expect(tokenASupply).to.equal(ownerBalance)
      expect(tokenBSupply).to.equal(ownerBalance)
    })

    it.skip("Delegatecall accessed the right target contract", async function () {

    })
  })

  // context("SHORT functions", function () {
  //   it("Should return totalAssets", async function () {
  //     console.log(gammaPool)
  //     const res = await (await gammaPool.totalAssets()).wait()
  //     console.log(res)
  //   })

  //   it("Should deposit assets to the pool", async function () {
  //     const res = await (await gammaPool.deposit(1000, addr1.address)).wait()
  //     console.log(res)
  //   })

  //   it("Should mint the shares", async function () {
  //     const res = await (await gammaPool.mint(1000, addr2.address)).wait()
  //     console.log(res)
  //   })

  //   it("Should withdraw", async function () {
  //     await (await gammaPool.deposit(1000, addr1.address)).wait()
  //     const res = await (await gammaPool.mint(1000, addr1.address, owner.address)).wait()
  //     console.log(res)
  //   })

  //   it("Should redeem", async function () {
  //     const res = await (await gammaPool.redeem(1000, owner.address, addr1.address)).wait()
  //     console.log(res)
  //   })
  // })
})
