pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../contracts/interfaces/math/ICPMMMath.sol";
import "../../contracts/libraries/cpmm/CPMMMath.sol";

contract MathTest is Test {

    ICPMMMath mathLib;

    function setUp() public {
        mathLib = new CPMMMath();
    }

    function testSqrt(uint8 num1, uint8 num2) public {
        num1 = uint8(bound(num1, 1, 1000));
        num2 = uint8(bound(num2, 1, 1000));

        assertGt(GSMath.sqrt(uint256(num1) * num2), 0);
        assertEq(GSMath.sqrt(1), 1);
        assertEq(GSMath.sqrt(2), 1);
        assertEq(GSMath.sqrt(3), 1);
        assertEq(GSMath.sqrt(4), 2);
        assertEq(GSMath.sqrt(5), 2);
        assertEq(GSMath.sqrt(7), 2);
        assertEq(GSMath.sqrt(8), 2);
        assertEq(GSMath.sqrt(9), 3);
        assertEq(GSMath.sqrt(100), 10);
        assertEq(GSMath.sqrt(99), 9);
        assertEq(GSMath.sqrt(1000), 31);
        assertEq(GSMath.sqrt(10000), 100);
        uint256 num3 = uint256(type(uint112).max) * 101 / 100;
        assertGt(GSMath.sqrt(num3 * num3), 0);
    }

    function rebalanceToCFMM(uint128 tokensHeld0, uint128 tokensHeld1, uint128 reserve0, uint128 reserve1, uint256 precision) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        uint256 leftVal = uint256(reserve0) * uint256(tokensHeld1);
        uint256 rightVal = uint256(reserve1) * uint256(tokensHeld0);

        bool checkRatio1 = tokensHeld0 >= 1e9 && tokensHeld1 >= 1e9 && reserve0 >= 1e9 && reserve1 > 1e9;
        bool checkRatio2 = tokensHeld0 >= 1e18 && tokensHeld1 >= 1e18 && reserve0 >= 1e18 && reserve1 > 1e18;

        if(leftVal > rightVal) {
            deltas = mathLib.calcDeltasForMaxLP(tokensHeld0, tokensHeld1, reserve0, reserve1, 997, 1000, 18);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 1st root (index 0) is the only feasible trade
            console.logInt(deltas[0]);
        } else if(leftVal < rightVal) {
            deltas = mathLib.calcDeltasForMaxLP(tokensHeld1, tokensHeld0, reserve1, reserve0, 997, 1000, 18);
            (deltas[0], deltas[1]) = (0, deltas[1]); // swap result, 1st root (index 0) is the only feasible trade
            console.logInt(deltas[1]);
        }

        if(deltas[0] > 0) {
            uint256 soldToken = uint256(reserve1) * (uint256(deltas[0])) * 1000;
            soldToken = soldToken / ((uint256(reserve0) - uint256(deltas[0])) * 997);
            tokensHeld1 -= uint128(soldToken);
            tokensHeld0 += uint128(uint256(deltas[0]));
            reserve1 += uint128(soldToken);
            reserve0 -= uint128(uint256(deltas[0]));
        } else if(deltas[1] > 0) {
            uint256 soldToken = uint256(reserve0) * uint256(deltas[1]) * 1000 / ((uint256(reserve1) - uint256(deltas[1])) * 997);
            tokensHeld0 -= uint128(soldToken);
            tokensHeld1 += uint128(uint256(deltas[1]));
            reserve0 += uint128(soldToken);
            reserve1 -= uint128(uint256(deltas[1]));
        }

        if(deltas[0] > 0 || deltas[1] > 0) {
            assertGe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1)/1e3, collateral0/1e3);
            uint256 cfmmRatio = uint256(reserve1) * 1e18 / uint256(reserve0);
            uint256 tokenRatio = uint256(tokensHeld1) * 1e18 / uint256(tokensHeld0);
            bool checkRatio = tokensHeld0 >= 1e18 && tokensHeld1 >= 1e18 && reserve0 >= 1e18 && reserve1 >= 1e18;
            if(checkRatio && precision <= 1e18) {
                assertEq(cfmmRatio/precision,tokenRatio/precision);
            }
        }
    }

    function testRebalanceToCFMMRatio(uint72 _tokensHeld0, uint72 _tokensHeld1, uint96 _reserve0, uint96 _reserve1) public {
        uint128 reserve1 = uint128(bound(_reserve1, type(uint80).max, type(uint96).max));
        uint128 reserve0 = reserve1 / 2;
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, GSMath.min(reserve0,type(uint72).max)/3, GSMath.min(reserve0,type(uint72).max)/2));
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, GSMath.min(reserve1,type(uint72).max)/2, GSMath.min(reserve1,type(uint72).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18);
    }

    function testRebalanceToCFMMRatio104x96(uint80 _tokensHeld0, uint80 _tokensHeld1, uint112 _reserve0, uint112 _reserve1) public {
        uint128 reserve0 = uint128(bound(_reserve0, 1000, type(uint104).max));
        uint128 reserve1 = uint128(bound(_reserve1, 1000, type(uint96).max));
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint80).max)));
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint80).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18+1);
    }

    function testRebalanceToCFMMRatio96x104(uint80 _tokensHeld0, uint80 _tokensHeld1, uint112 _reserve0, uint112 _reserve1) public {
        //uint128 reserve0 = uint128(bound(_reserve0, 1000, type(uint96).max));
        uint128 reserve1 = uint128(bound(_reserve1, 1000, type(uint104).max));
        uint128 reserve0 = (reserve1 + 2000)/ 2;
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint80).max)));
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint80).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18+1);
    }

    function testRebalanceToCFMMRatio112x88(uint80 _tokensHeld0, uint80 _tokensHeld1, uint112 _reserve0, uint112 _reserve1) public {
        //uint128 reserve0 = uint128(bound(_reserve0, 1000, type(uint112).max));
        uint128 reserve1 = uint128(bound(_reserve1, 1000, type(uint88).max));
        uint128 reserve0 = (reserve1 + 2000)/ 2;
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint80).max)));
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint80).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18+1);
    }

    function testRebalanceToCFMMRatio88x112(uint80 _tokensHeld0, uint80 _tokensHeld1, uint112 _reserve0, uint112 _reserve1) public {
        uint128 reserve0 = uint128(bound(_reserve0, 1000, type(uint88).max));
        uint128 reserve1 = uint128(bound(_reserve1, 1000, type(uint112).max));
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint80).max)));
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint80).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18+1);
    }

    function testRebalanceToCFMMRatio96x112(uint80 _tokensHeld0, uint80 _tokensHeld1, uint112 _reserve0, uint112 _reserve1) public {
        uint128 reserve0 = uint128(bound(_reserve0, 1, type(uint96).max));
        uint128 reserve1 = uint128(bound(_reserve1, 1, type(uint112).max));
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint64).max)));
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint64).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18 + 1);

        reserve0 = uint128(bound(_reserve0, 1, type(uint96).max));
        reserve1 = uint128(bound(_reserve1, 1, type(uint112).max));
        tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint72).max)));
        tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint72).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18 + 1);

        reserve0 = uint128(bound(_reserve0, 1, type(uint96).max));
        reserve1 = uint128(bound(_reserve1, 1, type(uint112).max));
        tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint80).max)));
        tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint80).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18 + 1);
    }

    function testRebalanceToCFMMRatio112x96(uint80 _tokensHeld0, uint80 _tokensHeld1, uint112 _reserve0, uint112 _reserve1) public {
        uint128 reserve0 = uint128(bound(_reserve0, 1, type(uint96).max));
        uint128 reserve1 = uint128(bound(_reserve1, 1, type(uint112).max));
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint64).max)));
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint64).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18 + 1);

        reserve0 = uint128(bound(_reserve0, 1, type(uint96).max));
        reserve1 = uint128(bound(_reserve1, 1, type(uint112).max));
        tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint72).max)));
        tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint72).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18 + 1);

        reserve0 = uint128(bound(_reserve0, 1, type(uint112).max));
        reserve1 = uint128(bound(_reserve1, 1, type(uint96).max));
        tokensHeld0 = uint128(bound(_tokensHeld0, 1, GSMath.min(reserve0,type(uint80).max)));
        tokensHeld1 = uint128(bound(_tokensHeld1, 1, GSMath.min(reserve1,type(uint80).max)));

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18 + 1);
    }
}
