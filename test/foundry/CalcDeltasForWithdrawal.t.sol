pragma solidity ^0.8.0;

import "./CalcDeltasBase.sol";

contract CalcDeltasForWithdrawal is CalcDeltasBase {

    function rebalanceToWithdraw(uint256[] memory amounts, uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 precision, uint8 decimals0, uint8 decimals1, bool checkCollateral) internal {
        uint256 collateral0 = GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1);
        int256[] memory deltas = new int256[](2);

        if(amounts[0] > 0) {
            deltas = mathLib.calcDeltasForWithdrawal(amounts[0], ratio[0], ratio[1], tokensHeld0, tokensHeld1,
                reserve0, reserve1, fee1, fee2);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 2nd root (index 1) is the only feasible trade
        } else if(amounts[1] > 0){
            deltas = mathLib.calcDeltasForWithdrawal(amounts[1], ratio[1], ratio[0], tokensHeld1, tokensHeld0,
                reserve1, reserve0, fee1, fee2);
            deltas[0] = 0; // 2nd root (index 1) is the only feasible trade
        } // otherwise no trade

        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            deltas[0], deltas[1]);

        if(deltas[0] > 0) {
            tokensHeld0 -= uint128(amounts[0]);
        } else if(deltas[1] > 0) {
            tokensHeld1 -= uint128(amounts[1]);
        }

        if(deltas[0] > 0 || deltas[1] > 0) {
            if(checkCollateral) {
                assertLe(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1)/1e3, collateral0/1e3);
            }
            bool checkRatio = tokensHeld0 >= (10**decimals0) && tokensHeld1 >= (10**decimals1) &&
                reserve0 >= (10**decimals0) && reserve1 >= (10**decimals1);
            if(checkRatio && precision <= 1e18) {
                uint256 cfmmRatio = uint256(ratio[1]) * (10**decimals0) / uint256(ratio[0]);
                uint256 tokenRatio = uint256(tokensHeld1) * (10**decimals0) / uint256(tokensHeld0);
                uint256 diff = cfmmRatio > tokenRatio ? cfmmRatio - tokenRatio : tokenRatio - cfmmRatio;
                assertEq(diff/precision,0);
            }
        }
    }

    function rebalanceToWithdrawCasesByRatio(uint8[] memory decimals, uint8 amtFactor, bool side, uint256 precision) internal {
        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = side ? tokensHeld0 * amtFactor / 100 : 0;
        amounts[1] = !side ? tokensHeld1 * amtFactor / 100 : 0;

        uint256[] memory ratio = new uint256[](2);

        // ratio = token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1;
        rebalanceToWithdrawByReserves(amounts, ratio, tokensHeld0, tokensHeld1, decimals[0], decimals[1], precision);

        // ratio < token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1 / 2;
        rebalanceToWithdrawByReserves(amounts, ratio, tokensHeld0, tokensHeld1, decimals[0], decimals[1], precision);

        // ratio > token
        ratio[0] = tokensHeld0;
        ratio[1] = tokensHeld1 * 2;
        rebalanceToWithdrawByReserves(amounts, ratio, tokensHeld0, tokensHeld1, decimals[0], decimals[1], precision);
    }

    function rebalanceToWithdrawByReserves(uint256[] memory amounts, uint256[] memory ratio, uint128 tokensHeld0, uint128 tokensHeld1,
        uint8 decimals0, uint8 decimals1, uint256 precision) internal {

        // token = cfmm
        uint128 reserve0 = tokensHeld0 * 100;//10_000 * 1e18;
        uint128 reserve1 = tokensHeld1 * 100;//1_000_000 * 1e18;
        rebalanceToWithdraw(amounts, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, decimals0, decimals1, false);

        // token < cfmm
        reserve0 = tokensHeld0 * 100; //10_000 * 1e18;
        reserve1 = tokensHeld1 * 100 * 200; //2_000_000 * 1e18;
        rebalanceToWithdraw(amounts, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, decimals0, decimals1, false);

        // token > cfmm
        reserve0 = tokensHeld0 * 100 * 200; //2_000_000 * 1e18;
        reserve1 = tokensHeld1 * 100; //10_000 * 1e18;
        rebalanceToWithdraw(amounts, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, decimals0, decimals1, false);
    }

    function testRebalanceToWithdrawFixed() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 18;

        uint8 amtFactor = 50;

        rebalanceToWithdrawCasesByRatio(decimals, amtFactor, true, 1e1);
        rebalanceToWithdrawCasesByRatio(decimals, amtFactor, false, 1e1);
    }

    function testRebalanceToWithdrawFixed6x18() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 6;
        decimals[1] = 18;

        uint8 amtFactor = 50;

        rebalanceToWithdrawCasesByRatio(decimals, amtFactor, true, 1e12);
        rebalanceToWithdrawCasesByRatio(decimals, amtFactor, false, 1e12);
    }

    function testRebalanceToWithdrawFixed18x6() public {
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 6;

        uint8 amtFactor = 50;

        rebalanceToWithdrawCasesByRatio(decimals, amtFactor, true, 1e2);
        rebalanceToWithdrawCasesByRatio(decimals, amtFactor, false, 1e2);
    }

    function testRebalanceToWithdraw(bool side, uint8 move, uint8 amtFactor, uint8 borrow, uint112 _reserve0,
        uint112 _reserve1) public {
        amtFactor = uint8(bound(amtFactor, 100, 120));

        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
        createMarketPosition2(_reserve0, _reserve1, borrow, move, side);

        uint256[] memory ratio = createRatioParameter(tokensHeld0, tokensHeld1, move);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = side ? tokensHeld0 * amtFactor / 100 : 0;
        amounts[1] = !side ? tokensHeld1 * amtFactor / 100 : 0;

        rebalanceToWithdraw(amounts, ratio, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e12, 18, 18, true);
    }
}
