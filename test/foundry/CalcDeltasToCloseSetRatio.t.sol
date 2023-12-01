pragma solidity ^0.8.0;

import "./CalcDeltasBase.sol";

contract CalcDeltasToCloseSetRatio is CalcDeltasBase {

    function rebalanceToCloseSetRatio(uint256 liquidity, uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint8[] memory decimals, uint256 precision) internal {
        int256[] memory deltas = new int256[](2);

        {
            uint8 avgDecimals = (decimals[0] + decimals[1])/2;
            uint256 leftVal = ratio[1] * (10**avgDecimals);
            uint256 rightVal = ratio[0] * (10**avgDecimals);
            if(leftVal > rightVal) {
                deltas = mathLib.calcDeltasToCloseSetRatio(liquidity, ratio[0], ratio[1], tokensHeld0, tokensHeld1,
                    reserve0, reserve1, avgDecimals);
                (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 1st root (index 0) is the only feasible trade
            } else if(leftVal < rightVal){
                deltas = mathLib.calcDeltasToCloseSetRatio(liquidity, ratio[1], ratio[0], tokensHeld1, tokensHeld0,
                    reserve1, reserve0, avgDecimals);
                (deltas[0], deltas[1]) = (0, deltas[1]); // swap result, 1st root (index 0) is the only feasible trade
            }
        }
        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            deltas[0], deltas[1]);

        uint256 lastCFMMInvariant = GSMath.sqrt(uint256(reserve0) * reserve1);
        uint256 payToken0 = liquidity * reserve0 / lastCFMMInvariant;
        uint256 payToken1 = liquidity * reserve1 / lastCFMMInvariant;
        tokensHeld0 -= uint128(payToken0);
        tokensHeld1 -= uint128(payToken1);
        reserve0 += uint128(payToken0);
        reserve1 += uint128(payToken1);
        bool checkRatio = tokensHeld0 >= (10**decimals[0]) && tokensHeld1 >= (10**decimals[1]) && reserve0 >= (10**decimals[0]) && reserve1 >= (10**decimals[1]);
        if(checkRatio && precision <= 1e18) {
            uint256 _ratio = uint256(ratio[1]) * (10**decimals[0]) / uint256(ratio[0]);
            uint256 tokenRatio = uint256(tokensHeld1) * (10**decimals[0]) / uint256(tokensHeld0);
            assertApproxEqRel(_ratio,tokenRatio,precision);
        }
    }

    function rebalanceToCloseSetRatioCasesByRatio(uint8[] memory decimals, uint256 precision) internal {
        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        uint256 collateral = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1); // 1_000 * 1e18
        uint128 liquidity = uint128(collateral / 2);

        uint256[] memory ratio = new uint256[](2);

        // ratio = token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1;
        rebalanceToCloseSetRatioCasesByReserves(liquidity, ratio, tokensHeld0, tokensHeld1, decimals, precision);

        // ratio < token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1 / 2;
        rebalanceToCloseSetRatioCasesByReserves(liquidity, ratio, tokensHeld0, tokensHeld1, decimals, precision);

        // ratio > token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1 * 2;
        rebalanceToCloseSetRatioCasesByReserves(liquidity, ratio, tokensHeld0, tokensHeld1, decimals, precision);
    }

    function rebalanceToCloseSetRatioCasesByReserves(uint256 liquidity, uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint8[] memory decimals, uint256 precision) internal {
        // token = cfmm
        uint128 reserve0 = tokensHeld0 * 100;//10_000 * 1e18;
        uint128 reserve1 = tokensHeld1 * 100;//1_000_000 * 1e18;
        rebalanceToCloseSetRatio(liquidity, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, decimals, precision);

        // token < cfmm
        reserve0 = tokensHeld0 * 100; //10_000 * 1e18;
        reserve1 = tokensHeld1 * 100 * 200; //2_000_000 * 1e18;
        rebalanceToCloseSetRatio(liquidity, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, decimals, precision);

        // token > cfmm
        reserve0 = tokensHeld0 * 100 * 200; //2_000_000 * 1e18;
        reserve1 = tokensHeld1 * 100; //10_000 * 1e18;
        rebalanceToCloseSetRatio(liquidity, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, decimals, precision);
    }

    function testRebalanceToCloseSetRatioFixed() public {
        fee1 = 1000;
        fee2 = 1000;

        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 18;

        rebalanceToCloseSetRatioCasesByRatio(decimals, 1e14);
    }

    function testRebalanceToCloseSetRatioFixed18x6() public {
        fee1 = 1000;
        fee2 = 1000;

        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 6;

        rebalanceToCloseSetRatioCasesByRatio(decimals, 1e14);
    }

    function testRebalanceToCloseSetRatioFixed6x18() public {
        fee1 = 1000;
        fee2 = 1000;

        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 6;
        decimals[1] = 18;

        rebalanceToCloseSetRatioCasesByRatio(decimals, 1e14);
    }

    function testRebalanceToCloseSetRatio(bool side, uint8 amtFactor, uint8 move, uint8 borrow,
        uint112 _reserve0, uint112 _reserve1) public {

        fee1 = 1000;
        fee2 = 1000;

        if(amtFactor < 10) amtFactor = 10;

        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
            createMarketPosition2(_reserve0, _reserve1, borrow, move < 128 ? 128 : move, side, 1e6);

        uint256[] memory ratio = new uint256[](2);
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1;

        uint256 liquidity = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1) * amtFactor / 500;

        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 18;

        rebalanceToCloseSetRatio(liquidity, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, decimals, 1e14);
    }
}
