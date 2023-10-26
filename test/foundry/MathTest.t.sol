pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../contracts/interfaces/math/ICPMMMath.sol";
import "../../contracts/libraries/cpmm/CPMMMath.sol";

contract MathTest is Test {

    ICPMMMath mathLib;

    function setUp() public {
        mathLib = new CPMMMath();
    }

}
