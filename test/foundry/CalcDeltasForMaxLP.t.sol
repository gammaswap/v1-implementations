pragma solidity ^0.8.0;

import "./CalcDeltasBase.sol";

contract CalcDeltasForMaxLP is CalcDeltasBase {

    function rebalanceToCFMM(uint128 tokensHeld0, uint128 tokensHeld1, uint128 reserve0, uint128 reserve1,
        uint8 decimals0, uint8 decimals1, uint256 precision) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        uint256 leftVal = uint256(reserve0) * uint256(tokensHeld1);
        uint256 rightVal = uint256(reserve1) * uint256(tokensHeld0);

        if(leftVal > rightVal) {
            deltas = mathLib.calcDeltasForMaxLP(tokensHeld0, tokensHeld1, reserve0, reserve1, fee1, fee2, decimals0);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) {
            deltas = mathLib.calcDeltasForMaxLP(tokensHeld1, tokensHeld0, reserve1, reserve0, fee1, fee2, decimals0);
            (deltas[0], deltas[1]) = (0, deltas[1]); // swap result, 1st root (index 0) is the only feasible trade
        }

        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            deltas[0], deltas[1]);

        if(deltas[0] > 0 || deltas[1] > 0) {
            assertGe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1), collateral0); // when rebalancing is small it might not pass
            bool checkRatio = tokensHeld0 >= (10**decimals0) && tokensHeld1 >= (10**decimals1) &&
                reserve0 >= (10**decimals0) && reserve1 >= (10**decimals1);
            if(checkRatio && precision <= 1e18) {
                uint256 cfmmRatio = uint256(reserve1) * (10**decimals0) / uint256(reserve0);
                uint256 tokenRatio = uint256(tokensHeld1) * (10**decimals0) / uint256(tokensHeld0);
                uint256 diff = cfmmRatio > tokenRatio ? cfmmRatio - tokenRatio : tokenRatio - cfmmRatio;
                assertEq(diff/precision,0);
            }
        }
    }

    function rebalanceToCFMMCasesByReserves(uint128 tokensHeld0, uint128 tokensHeld1,
        uint8[] memory decimals, uint256 precision) internal {
        // token = cfmm
        uint128 reserve0 = tokensHeld0 * 100;//10_000 * 1e18;
        uint128 reserve1 = tokensHeld1 * 100;//1_000_000 * 1e18;
        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, decimals[0], decimals[1], precision);

        // token < cfmm
        reserve0 = tokensHeld0 * 100; //10_000 * 1e18;
        reserve1 = tokensHeld1 * 100 * 200; //2_000_000 * 1e18;
        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, decimals[0], decimals[1], precision);

        // token > cfmm
        reserve0 = tokensHeld0 * 100 * 200; //2_000_000 * 1e18;
        reserve1 = tokensHeld1 * 100; //10_000 * 1e18;
        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, decimals[0], decimals[1], precision);
    }

    function testRebalanceToCFMMRatioFixed() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 18;

        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        rebalanceToCFMMCasesByReserves(tokensHeld0, tokensHeld1, decimals, 1e2);
    }

    function testRebalanceToCFMMRatioFixed6x18() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 6;
        decimals[1] = 18;

        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        rebalanceToCFMMCasesByReserves(tokensHeld0, tokensHeld1, decimals, 1e13);
    }

    function testRebalanceToCFMMRatioFixed18x6() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 6;

        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        rebalanceToCFMMCasesByReserves(tokensHeld0, tokensHeld1, decimals, 1e0);
    }

    function testRebalanceToCFMMRatio(uint112 _reserve0, uint112 _reserve1, uint8 borrow, uint8 move, bool side) public {
        if(move < 128) move = 128;

        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
            createMarketPosition2(_reserve0, _reserve1, borrow, move, side);

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 18, 18, 1e10);
        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 6, 18, 1e4);
        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 18, 6, 1e8);
    }
}
