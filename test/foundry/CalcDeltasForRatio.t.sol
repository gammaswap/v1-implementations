pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../contracts/interfaces/math/ICPMMMath.sol";
import "../../contracts/libraries/cpmm/CPMMMath.sol";

contract CalcDeltasToRatio is Test {

    ICPMMMath mathLib;

    function setUp() public {
        mathLib = new CPMMMath();
    }

    function rebalanceToRatio(uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 precision) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        bool checkRatio1 = tokensHeld0 >= 1e9 && tokensHeld1 >= 1e9 && reserve0 >= 1e9 && reserve1 > 1e9;
        bool checkRatio2 = tokensHeld0 >= 1e18 && tokensHeld1 >= 1e18 && reserve0 >= 1e18 && reserve1 > 1e18;

        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio
        uint256 leftVal = uint256(ratio[1]) * uint256(tokensHeld0);
        uint256 rightVal = uint256(ratio[0]) * uint256(tokensHeld1);
        if(leftVal > rightVal) { // sell token0, buy token1 (need more token1)
            console.log("leftValcalc1");
            deltas = mathLib.calcDeltasForRatio(ratio[1], ratio[0], tokensHeld1, tokensHeld0, reserve1, reserve0, 997, 1000);
            console.log("leftValcalc2");
            console.logInt(deltas[0]);
            console.logInt(deltas[1]);
            (deltas[0], deltas[1]) = (0, deltas[0]); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) { // buy token0, sell token1 (need more token0)
            console.log("rightValcalc1");
            deltas = mathLib.calcDeltasForRatio(ratio[0], ratio[1], tokensHeld0, tokensHeld1, reserve0, reserve1, 997, 1000);
            console.log("rightValcalc2");
            deltas[1] = 0; // 1st quadratic root (index 0) is the only feasible trade
        } // otherwise no trade

        if(deltas[0] > 0) {
            console.log("yo1");
            console.logInt(deltas[0]);
            console.logInt(deltas[1]);
            //169512777839
            //44837859460
            uint256 soldToken = uint256(reserve1) * (uint256(deltas[0])) * 1000;
            soldToken = soldToken / ((uint256(reserve0) - uint256(deltas[0])) * 997);
            tokensHeld1 -= uint128(soldToken);
            tokensHeld0 += uint128(uint256(deltas[0]));
            reserve1 += uint128(soldToken);
            reserve0 -= uint128(uint256(deltas[0]));
        } else if(deltas[1] > 0) {
            console.log("yo2");
            console.logInt(deltas[0]);
            console.logInt(deltas[1]);
            uint256 soldToken = uint256(reserve0) * uint256(deltas[1]) * 1000 / ((uint256(reserve1) - uint256(deltas[1])) * 997);
            console.log("yo2a");
            console.log(soldToken);
            console.log("yo2b");
            console.log(tokensHeld0);
            tokensHeld0 -= uint128(soldToken);
            console.log("yo2c");
            console.log(tokensHeld1);
            tokensHeld1 += uint128(uint256(deltas[1]));
            console.log("yo2d");
            console.log(reserve0);
            reserve0 += uint128(soldToken);
            console.log("yo2e");
            console.log(reserve1);
            reserve1 -= uint128(uint256(deltas[1]));
        }

        console.log("yo3");
        if(deltas[0] > 0 || deltas[1] > 0) {
            console.log("yo4");
            assertLe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1)/1e3, collateral0/1e3);
            uint256 cfmmRatio = uint256(ratio[1]) * 1e18 / uint256(ratio[0]);
            uint256 tokenRatio = uint256(tokensHeld1) * 1e18 / uint256(tokensHeld0);
            bool checkRatio = tokensHeld0 >= 1e18 && tokensHeld1 >= 1e18 && reserve0 >= 1e18 && reserve1 >= 1e18;
            if(checkRatio && precision <= 1e18) {
                console.log("tokenRatio");
                console.log(tokenRatio);
                console.log("cfmmRatio");
                console.log(cfmmRatio);
                uint256 diff = tokenRatio > cfmmRatio ? tokenRatio - cfmmRatio : cfmmRatio - tokenRatio;
                assertLt(diff,precision);
            }
        }
    }

    function testRebalanceForRatio(uint112 _reserve0, uint112 _reserve1, uint24 ratio0, uint24 ratio1) public {
        uint256[] memory ratio = new uint256[](2);
        ratio[0] = uint128(bound(ratio0, 1, type(uint24).max));
        ratio[1] = uint128(bound(ratio1, 1, type(uint24).max));
        uint128 reserve1 = uint128(bound(_reserve1, type(uint80).max, type(uint104).max));
        uint128 reserve0 = uint128(bound(_reserve0, type(uint80).max, type(uint104).max));
        uint128 tokensHeld0 = reserve0/1e2;
        uint128 tokensHeld1 = reserve1/1e2;

        rebalanceToRatio(ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18);
    }

    function testRebalanceForRatio104(uint104 _reserve0, uint104 _reserve1, uint24 ratio0, uint24 ratio1) public {
        uint256[] memory ratio = new uint256[](2);
        ratio[1] = uint128(bound(ratio1, 10000, type(uint24).max));
        ratio[0] = ratio[1]/2;//uint128(bound(ratio0, 1000000, type(uint24).max));
        //uint128 reserve0 = uint128(bound(_reserve0, 1000000, type(uint104).max));
        //uint128 reserve1 = uint128(bound(_reserve1, 1000000, type(uint104).max));
        uint128 reserve0 = uint128(bound(_reserve0, 10000000, 1000000000000));
        uint128 reserve1 = uint128(bound(_reserve1, 10000000, 1000000000000));
        console.log("here1");
        uint128 tokensHeld0 = (reserve0/10);
        uint128 tokensHeld1 = (reserve1/10);

        console.log("reserves");
        console.log(reserve0);
        console.log(reserve1);
        console.log("tokensHelds");
        console.log(tokensHeld0);
        console.log(tokensHeld1);
        console.log("ratios");
        console.log(ratio[0]);
        console.log(ratio[1]);
        console.log("here2");
        rebalanceToRatio(ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18);
    }

}