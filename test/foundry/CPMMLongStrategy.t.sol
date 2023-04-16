pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "./fixtures/CPMMGammaSwapSetup.sol";

contract CPMMLongStrategyTest is CPMMGammaSwapSetup {

    address addr1;

    function setUp() public {
        super.initCPMMGammaSwap();
    }

    function testDeployment() public {
        console.log("hello");
    }

}
