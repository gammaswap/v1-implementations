// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const gsFactoryAddress = "<get this from core pre-strat deploy logs>";
  const cfmmFactoryAddress = "<get this from core pre-strat deploy logs>";
  const cfmmHash = "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f";

  const CPMMLongStrategy = await ethers.getContractFactory("CPMMLongStrategy");
  const longStrategy = await CPMMLongStrategy.deploy();
  await longStrategy.deployed();

  const CPMMShortStrategy = await ethers.getContractFactory("CPMMLongStrategy");
  const shortStrategy = await CPMMShortStrategy.deploy();
  await shortStrategy.deployed();

  const abi = ethers.utils.defaultAbiCoder;
  const params = abi.encode(
    [
      "address",
      "bytes32",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256"],
    [
      cfmmFactoryAddress,
      cfmmHash,
      1000,
      997,
      10 ^ 16,
      8 * 10 ^ 17,
      4 * 10 ^ 16,
      75 * 10 ^ 16
    ]
  );

  const CPMMProtocol = await ethers.getContractFactory("CPMMProtocol");
  const protocol = await CPMMProtocol.deploy(
    gsFactoryAddress,
    1,
    params,
    longStrategy.address,
    shortStrategy.address,
  );
  await protocol.deployed()
  console.log("CPMMProtocol Address >> " + protocol.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

