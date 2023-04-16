pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../contracts/test/TestERC20.sol";

contract TokensSetup is Test {

    TestERC20 public weth;
    TestERC20 public usdc;

    function initTokens() public {
        weth = new TestERC20("Wrapped Ethereum", "WETH");
        usdc = new TestERC20("USDC", "USDC");
    }
}