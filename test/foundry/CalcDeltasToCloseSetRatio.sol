pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../contracts/interfaces/math/ICPMMMath.sol";
import "../../contracts/libraries/cpmm/CPMMMath.sol";

contract CalcDeltasToCloseSetRatio is Test {

    ICPMMMath mathLib;

    function setUp() public {
        mathLib = new CPMMMath();
    }

    function rebalanceToCloseSetRatio(uint256 liquidity, uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 precision) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio

        uint256 leftVal = uint256(reserve0) * uint256(tokensHeld1);
        uint256 rightVal = uint256(reserve1) * uint256(tokensHeld0);

        if(leftVal > rightVal) {
            deltas = mathLib.calcDeltasToCloseSetRatio(liquidity, ratio[0], ratio[1], tokensHeld0, tokensHeld1, reserve0, reserve1, 18, 18);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) {
            deltas = mathLib.calcDeltasToCloseSetRatio(liquidity, ratio[1], ratio[0], tokensHeld1, tokensHeld0, reserve1, reserve0, 18, 18);
            (deltas[0], deltas[1]) = (0, deltas[1]); // swap result, 1st root (index 0) is the only feasible trade
        }

        if(deltas[0] > 0) {
            console.log("yo1");
            console.logInt(deltas[0]);
            console.logInt(deltas[1]);
            //169512777839
            //44837859460
            uint256 soldToken = uint256(reserve1) * (uint256(deltas[0])) * 1000;
            soldToken = soldToken / ((uint256(reserve0) - uint256(deltas[0])) * 997);
            console.log("yo2a");
            console.log(soldToken);
            console.log(tokensHeld1);
            console.log(tokensHeld0);
            console.log(reserve1);
            console.log(reserve0);
            tokensHeld1 -= uint128(soldToken);
            console.log("yo2b");
            tokensHeld0 += uint128(uint256(deltas[0]));
            console.log("yo2c");
            reserve1 += uint128(soldToken);
            console.log("yo2d");
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
            uint256 cfmmRatio = uint256(ratio[1]) * 1e18 / uint256(ratio[0]);
            uint256 tokenRatio = uint256(tokensHeld1) * 1e18 / uint256(tokensHeld0);
            console.log("tokensHeld");
            console.log(tokensHeld0);
            console.log(tokensHeld1);
            console.log("ratio");
            console.log(ratio[0]);
            console.log(ratio[1]);
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

    function testRebalanceToCloseSetRatio(uint8 amtFactor, uint72 _tokensHeld0, uint72 _tokensHeld1,
        uint112 _reserve0, uint112 _reserve1, uint24 ratio0, uint24 ratio1) public {
        amtFactor = uint8(bound(amtFactor, 10, type(uint8).max));
        uint256[] memory ratio = new uint256[](2);
        ratio[0] = uint128(bound(ratio0, 10000000, type(uint24).max));
        ratio[1] = uint128(bound(ratio1, 10000000, type(uint24).max));
        uint128 reserve1 = uint128(bound(_reserve1, type(uint80).max, type(uint96).max))/1e10;
        uint128 reserve0 = reserve1 / 2;
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, GSMath.min(reserve0,type(uint72).max)/3, GSMath.min(reserve0,type(uint72).max)/2))/1e10;
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, GSMath.min(reserve1,type(uint72).max)/2, GSMath.min(reserve1,type(uint72).max)))/1e10;

        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1;

        uint256 liquidity = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1) * amtFactor / type(uint8).max;

        console.log(tokensHeld0);
        console.log(tokensHeld1);
        console.log(reserve0);
        console.log(reserve1);
        console.log(ratio[0]);
        console.log(ratio[1]);
        console.log("Ratios");
        console.log(uint256(reserve1) * 1e18 / reserve0);
        console.log(uint256(tokensHeld1) * 1e18 / tokensHeld0);
        console.log(uint256(ratio[1]) * 1e18 / ratio[0]);
        console.log("---");
        rebalanceToCloseSetRatio(liquidity, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18);
    }
}
