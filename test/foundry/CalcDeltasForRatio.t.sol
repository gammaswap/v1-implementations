pragma solidity ^0.8.0;

import "./CalcDeltasBase.sol";

contract CalcDeltasToRatio is CalcDeltasBase {

    function rebalanceToRatio(uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 precision, uint8 decimals0, bool checkCollateral) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio
        uint256 leftVal = uint256(ratio[1]) * uint256(tokensHeld0);
        uint256 rightVal = uint256(ratio[0]) * uint256(tokensHeld1);
        if(leftVal > rightVal) { // sell token0, buy token1 (need more token1)
            deltas = mathLib.calcDeltasForRatio(ratio[1], ratio[0], tokensHeld1, tokensHeld0, reserve1, reserve0, fee1, fee2);
            (deltas[0], deltas[1]) = (0, deltas[0]); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) { // buy token0, sell token1 (need more token0)
            deltas = mathLib.calcDeltasForRatio(ratio[0], ratio[1], tokensHeld0, tokensHeld1, reserve0, reserve1, fee1, fee2);
            deltas[1] = 0; // 1st quadratic root (index 0) is the only feasible trade
        } // otherwise no trade

        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            deltas[0], deltas[1]);

        if(deltas[0] > 0 || deltas[1] > 0) {
            if(checkCollateral) {
                assertLe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1), collateral0);
            }
            bool checkRatio = tokensHeld0 >= (10**decimals0) && tokensHeld1 >= 1e6 && reserve0 >= (10**decimals0) && reserve1 >= 1e12;
            if(checkRatio && precision <= 1e18) {
                uint256 cfmmRatio = uint256(ratio[1]) * (10**decimals0) / uint256(ratio[0]);
                uint256 tokenRatio = uint256(tokensHeld1) * (10**decimals0) / uint256(tokensHeld0);
                uint256 diff = cfmmRatio > tokenRatio ? cfmmRatio - tokenRatio : tokenRatio - cfmmRatio;
                assertEq(diff/precision,0);
            }
        }
    }

    function rebalanceForRatioCasesByRatio(uint8[] memory decimals, uint256 precision) internal {
        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        uint256[] memory ratio = new uint256[](2);

        // ratio = token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1;
        rebalanceForRatioCasesByReserves(ratio, tokensHeld0, tokensHeld1, decimals[0], precision);

        // ratio < token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1 / 2;
        rebalanceForRatioCasesByReserves(ratio, tokensHeld0, tokensHeld1, decimals[0], precision);

        // ratio > token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1 * 2;
        rebalanceForRatioCasesByReserves(ratio, tokensHeld0, tokensHeld1, decimals[0], precision);
    }

    function rebalanceForRatioCasesByReserves(uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint8 decimals0, uint256 precision) internal {
        // token = cfmm
        uint128 reserve0 = tokensHeld0 * 100;//10_000 * 1e18;
        uint128 reserve1 = tokensHeld1 * 100;//1_000_000 * 1e18;
        rebalanceToRatio(ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, decimals0, false);

        // token < cfmm
        reserve0 = tokensHeld0 * 100; //10_000 * 1e18;
        reserve1 = tokensHeld1 * 100 * 200; //2_000_000 * 1e18;
        rebalanceToRatio(ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, decimals0, false);

        // token > cfmm
        reserve0 = tokensHeld0 * 100 * 200; //2_000_000 * 1e18;
        reserve1 = tokensHeld1 * 100; //10_000 * 1e18;
        rebalanceToRatio(ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, decimals0, false);
    }

    function testRebalanceForRatioFixed() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 18;

        rebalanceForRatioCasesByRatio(decimals, 1e2);
    }

    function testRebalanceForRatioFixed18x6() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 6;

        rebalanceForRatioCasesByRatio(decimals, 1e2);
    }

    function testRebalanceForRatioFixed6x18() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 6;
        decimals[1] = 18;

        rebalanceForRatioCasesByRatio(decimals, 1e14);
    }

    function testRebalanceForRatio(uint112 _reserve0, uint112 _reserve1, uint8 borrow,
        bool side, uint8 move) public {
        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
            createMarketPosition2(_reserve0, _reserve1, borrow, 0, side, 1e6);

        uint256[] memory ratio = createRatioParameter(tokensHeld0, tokensHeld1, move);

        rebalanceToRatio(ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e12, 18, true);
    }
}