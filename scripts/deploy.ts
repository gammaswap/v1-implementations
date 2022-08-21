// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
import { ethers } from "hardhat";
import type { TestERC20 } from "../typechain/TestERC20";

async function main() {
  const [owner, addr1, addr2, addr3] = await ethers.getSigners();
  const TestERC20Contract = await ethers.getContractFactory("TestERC20");
  const tokenA = await TestERC20Contract.deploy("Test Token A", "TOKA");
  const tokenB = await TestERC20Contract.deploy("Test Token B", "TOKB");
  const tokenC = await TestERC20Contract.deploy("Test Token C", "TOKC");
  const WETH = await TestERC20Contract.deploy("WETH", "WETH");
  await tokenA.deployed();
  await tokenB.deployed();
  await tokenC.deployed();
  await WETH.deployed();

  const UniswapV2Factory = new ethers.ContractFactory(
    UniswapV2FactoryJSON.abi,
    UniswapV2FactoryJSON.bytecode,
    owner
  );
  const uniFactory = await UniswapV2Factory.deploy(owner.address);
  await uniFactory.deployed();
  console.log("UniswapV2Factory Address >> " + uniFactory.address);

  async function createPair(token1: TestERC20, token2: TestERC20) {
    await uniFactory.createPair(token1.address, token2.address);
    const uniPairAddress: string = await uniFactory.getPair(
      token1.address,
      token2.address
    );
    const token1Symbol = await token1.symbol();
    const token2Symbol = await token2.symbol();
    console.log(token1Symbol + "/" + token2Symbol + " uniPairAddress >> "
      + uniPairAddress);
  }

  await createPair(tokenA, tokenB);
  await createPair(tokenA, tokenC);
  await createPair(tokenB, tokenC);
  await createPair(tokenA, WETH);
  await createPair(tokenB, WETH);
  await createPair(tokenC, WETH);
  
  const GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
  const factory = await GammaPoolFactory.deploy(owner.address);
  await factory.deployed()
  console.log("GammaPoolFactory Address >> " + factory.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

