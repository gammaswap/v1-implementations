pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../contracts/interfaces/math/ICPMMMath.sol";
import "../../contracts/libraries/cpmm/CPMMMath.sol";

contract CalcDeltasForWithdrawal is Test {

    ICPMMMath mathLib;

    function setUp() public {
        mathLib = new CPMMMath();
    }

    function rebalanceToWithdraw(uint256[] memory amounts, uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 precision) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio

        if(amounts[0] > 0) {
            deltas = mathLib.calcDeltasForWithdrawal(amounts[0], ratio[0], ratio[1], tokensHeld0, tokensHeld1, reserve0, reserve1, 997, 1000);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 2nd root (index 1) is the only feasible trade
        } else if(amounts[1] > 0){
            deltas = mathLib.calcDeltasForWithdrawal(amounts[1], ratio[1], ratio[0], tokensHeld1, tokensHeld0, reserve1, reserve0, 997, 1000);
            deltas[0] = 0; // 2nd root (index 1) is the only feasible trade
        } // otherwise no trade

        if(deltas[0] > 0) {
            console.log("yo1");
            console.logInt(deltas[0]);
            console.logInt(deltas[1]);
            //169512777839
            //44837859460
            uint256 soldToken = uint256(reserve1) * (uint256(deltas[0])) * 1000;
            soldToken = soldToken / ((uint256(reserve0) - uint256(deltas[0])) * 997);
            console.log("yo2a");
            console.log(amounts[0]);
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
            console.log("yo2e");
            tokensHeld0 -= uint128(amounts[0]);
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
            tokensHeld1 -= uint128(amounts[1]);
        }

        console.log("yo3");
        if(deltas[0] > 0 || deltas[1] > 0) {
            console.log("yo4");
            assertLe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1)/1e3, collateral0/1e3);
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

    function testRebalanceToWithdraw(bool side, uint8 amtFactor, uint72 _tokensHeld0, uint72 _tokensHeld1, uint112 _reserve0,
        uint112 _reserve1, uint24 ratio0, uint24 ratio1) public {
        amtFactor = uint8(bound(amtFactor, 110, 130));
        uint256[] memory ratio = new uint256[](2);
        ratio[0] = uint128(bound(ratio0, 100000, type(uint24).max));
        ratio[1] = uint128(bound(ratio1, 100000, type(uint24).max));
        uint128 reserve1 = uint128(bound(_reserve1, type(uint80).max, type(uint96).max))/1e10;
        uint128 reserve0 = reserve1 / 2;
        uint128 tokensHeld0 = uint128(bound(_tokensHeld0, GSMath.min(reserve0,type(uint72).max)/3, GSMath.min(reserve0,type(uint72).max)/2))/1e10;
        uint128 tokensHeld1 = uint128(bound(_tokensHeld1, GSMath.min(reserve1,type(uint72).max)/2, GSMath.min(reserve1,type(uint72).max)))/1e10;

        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = side ? tokensHeld0 * amtFactor / 100 : 0;
        amounts[1] = !side ? tokensHeld1 * amtFactor / 100 : 0;

        //amounts[0] = amounts[1];
        //amounts[1] = 0;
        console.log("amounts");
        console.log(amounts[0]);
        console.log(amounts[1]);
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
        rebalanceToWithdraw(amounts, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e18);
    }
}
