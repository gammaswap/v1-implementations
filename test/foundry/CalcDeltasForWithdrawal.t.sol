pragma solidity ^0.8.0;

import "./CalcDeltasBase.sol";

contract CalcDeltasForWithdrawal is CalcDeltasBase {

    function rebalanceToWithdraw(uint256[] memory amounts, uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 precision) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        if(amounts[0] > 0) {
            deltas = mathLib.calcDeltasForWithdrawal(amounts[0], ratio[0], ratio[1], tokensHeld0, tokensHeld1,
                reserve0, reserve1, 997, 1000);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 2nd root (index 1) is the only feasible trade
        } else if(amounts[1] > 0){
            deltas = mathLib.calcDeltasForWithdrawal(amounts[1], ratio[1], ratio[0], tokensHeld1, tokensHeld0,
                reserve1, reserve0, 997, 1000);
            deltas[0] = 0; // 2nd root (index 1) is the only feasible trade
        } // otherwise no trade

        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            uint256(deltas[0]), uint256(deltas[1]));

        if(deltas[0] > 0) {
            tokensHeld0 -= uint128(amounts[0]);
        } else if(deltas[1] > 0) {
            tokensHeld1 -= uint128(amounts[1]);
        }

        if(deltas[0] > 0 || deltas[1] > 0) {
            assertLe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1)/1e3, collateral0/1e3);
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

    function testRebalanceToWithdraw(bool side, uint8 move, uint8 amtFactor, uint8 borrow, uint112 _reserve0,
        uint112 _reserve1) public {
        amtFactor = uint8(bound(amtFactor, 100, 120));

        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
        createMarketPosition(_reserve0, _reserve1, borrow, move, side);

        uint256[] memory ratio = createRatioParameter(tokensHeld0, tokensHeld1, move);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = side ? tokensHeld0 * amtFactor / 100 : 0;
        amounts[1] = !side ? tokensHeld1 * amtFactor / 100 : 0;

        rebalanceToWithdraw(amounts, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e8);
    }
}
