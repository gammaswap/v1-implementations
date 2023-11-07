pragma solidity ^0.8.0;

import "./CalcDeltasBase.sol";

contract CalcDeltasToRatio is CalcDeltasBase {

    function rebalanceToRatio(uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 precision) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio
        uint256 leftVal = uint256(ratio[1]) * uint256(tokensHeld0);
        uint256 rightVal = uint256(ratio[0]) * uint256(tokensHeld1);
        if(leftVal > rightVal) { // sell token0, buy token1 (need more token1)
            deltas = mathLib.calcDeltasForRatio(ratio[1], ratio[0], tokensHeld1, tokensHeld0, reserve1, reserve0, 997, 1000);
            (deltas[0], deltas[1]) = (0, deltas[0]); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) { // buy token0, sell token1 (need more token0)
            deltas = mathLib.calcDeltasForRatio(ratio[0], ratio[1], tokensHeld0, tokensHeld1, reserve0, reserve1, 997, 1000);
            deltas[1] = 0; // 1st quadratic root (index 0) is the only feasible trade
        } // otherwise no trade

        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            uint256(deltas[0]), uint256(deltas[1]));

        if(deltas[0] > 0 || deltas[1] > 0) {
            assertLe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1), collateral0);
            uint256 cfmmRatio = uint256(ratio[1]) * 1e18 / uint256(ratio[0]);
            uint256 tokenRatio = uint256(tokensHeld1) * 1e18 / uint256(tokensHeld0);
            bool checkRatio = tokensHeld0 >= 1e12 && tokensHeld1 >= 1e12 && reserve0 >= 1e12 && reserve1 >= 1e12;
            if(checkRatio && precision <= 1e18) {
                cfmmRatio = cfmmRatio/(1e18);
                tokenRatio = tokenRatio/(1e18);
                uint256 diff = cfmmRatio > tokenRatio ? cfmmRatio - tokenRatio : tokenRatio - cfmmRatio;
                assertEq(diff/precision,0);
            }
        }
    }

    function testRebalanceForRatio(uint112 _reserve0, uint112 _reserve1, uint8 borrow,
        bool side, uint8 move) public {
        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
            createMarketPosition(_reserve0, _reserve1, borrow, 0, side);

        uint256[] memory ratio = createRatioParameter(tokensHeld0, tokensHeld1, move);

        rebalanceToRatio(ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e12);
    }
}