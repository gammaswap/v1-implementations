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
            deltas = mathLib.calcDeltasForMaxLP(tokensHeld0, tokensHeld1, reserve0, reserve1, 997, 1000, decimals0);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) {
            deltas = mathLib.calcDeltasForMaxLP(tokensHeld1, tokensHeld0, reserve1, reserve0, 997, 1000, decimals0);
            (deltas[0], deltas[1]) = (0, deltas[1]); // swap result, 1st root (index 0) is the only feasible trade
        }

        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            uint256(deltas[0]), uint256(deltas[1]));

        if(deltas[0] > 0 || deltas[1] > 0) {
            assertGe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1), collateral0); // when rebalancing is small it might not pass
            uint256 cfmmRatio = uint256(reserve1) * (10**decimals1) / uint256(reserve0);
            uint256 tokenRatio = uint256(tokensHeld1) * (10**decimals1) / uint256(tokensHeld0);
            bool checkRatio = tokensHeld0 >= 1e12 && tokensHeld1 >= 1e12 && reserve0 >= 1e12 && reserve1 >= 1e12;
            if(checkRatio && precision <= 1e18) {
                cfmmRatio = cfmmRatio/(10**decimals1);
                tokenRatio = tokenRatio/(10**decimals1);
                uint256 diff = cfmmRatio > tokenRatio ? cfmmRatio - tokenRatio : tokenRatio - cfmmRatio;
                assertEq(diff/precision,0);
            }
        }
    }

    function testRebalanceToCFMMRatio(uint112 _reserve0, uint112 _reserve1, uint8 borrow, uint8 move, bool side) public {
        if(move < 128) move = 128;

        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
            createMarketPosition(_reserve0, _reserve1, borrow, move, side);

        uint256 cfmmRatio = uint256(reserve1) * (10**18) / uint256(reserve0);
        uint256 tokenRatio = uint256(tokensHeld1) * (10**18) / uint256(tokensHeld0);

        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 18, 18, 1e8);
        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 6, 18, 1e10);
        rebalanceToCFMM(tokensHeld0, tokensHeld1, reserve0, reserve1, 18, 6, 1e10);
    }
}
