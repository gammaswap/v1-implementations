pragma solidity ^0.8.0;

import "./CalcDeltasBase.sol";

contract CalcDeltasToClose is CalcDeltasBase {

    function rebalanceToClose(bool side, uint256 liquidity, uint128 tokensHeld0, uint128 tokensHeld1, uint128 reserve0, uint128 reserve1,
        uint256 precision, uint128[] memory expected, uint8 idx) internal {

        uint256 lastCFMMInvariant = GSMath.sqrt(uint256(reserve0) * reserve1);

        int256[] memory deltas = new int256[](2);

        if(side) {
            deltas[0] = mathLib.calcDeltasToClose(liquidity, lastCFMMInvariant, tokensHeld0, reserve0);
        } else {
            deltas[1] = mathLib.calcDeltasToClose(liquidity, lastCFMMInvariant, tokensHeld1, reserve1);
        }

        (tokensHeld0, tokensHeld1, reserve0, reserve1) = updateTokenQtys(tokensHeld0, tokensHeld1, reserve0, reserve1,
            deltas[0], deltas[1]);

        lastCFMMInvariant = GSMath.sqrt(uint256(reserve0) * reserve1);
        uint256 payToken0 = liquidity * uint256(reserve0) / lastCFMMInvariant;
        uint256 payToken1 = liquidity * uint256(reserve1) / lastCFMMInvariant;

        tokensHeld0 -= uint128(payToken0);
        tokensHeld1 -= uint128(payToken1);
        reserve0 += uint128(payToken0);
        reserve1 += uint128(payToken1);

        if(deltas[0]!=0 || deltas[1] != 0) {
            if(side) {
                assertEq(tokensHeld0/precision, 0);
                assertGt(tokensHeld1, 0);
            } else {
                assertGt(tokensHeld0, 0);
                assertEq(tokensHeld1/precision, 0);
            }
        }

        if(idx > 0) {
            assertEq(expected[idx-1], tokensHeld0);
            assertEq(expected[idx], tokensHeld1);
        }
    }

    function rebalanceToCloseCasesByReserves(uint128 liquidity, uint128 tokensHeld0, uint128 tokensHeld1,
        uint256 precision, uint128[] memory expected) internal {

        // token = cfmm
        uint128 reserve0 = tokensHeld0 * 100; //10_000 * 1e18;
        uint128 reserve1 = tokensHeld1 * 100; //1_000_000 * 1e18;
        rebalanceToClose(true, liquidity, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, expected, 0);

        // token > cfmm, rebalance to token0, buy
        reserve0 = tokensHeld0 * 100 * 200; //2_000_000 * 1e18;
        reserve1 = tokensHeld1 * 100;       //10_000 * 1e18;
        rebalanceToClose(true, liquidity, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, expected, 3);

        // token > cfmm, rebalance to token1, sell
        reserve0 = tokensHeld0 * 100 * 200; //2_000_000 * 1e18;
        reserve1 = tokensHeld1 * 100;       //10_000 * 1e18;
        rebalanceToClose(false, liquidity, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, expected, 5);

        // token < cfmm, rebalance to token 0, sell
        reserve0 = tokensHeld0 * 100;       //10_000 * 1e18;
        reserve1 = tokensHeld1 * 100 * 200; //2_000_000 * 1e18;
        rebalanceToClose(true, liquidity, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, expected, 7);

        // token < cfmm, rebalance to token 1, buy
        reserve0 = tokensHeld0 * 100;       //10_000 * 1e18;
        reserve1 = tokensHeld1 * 100 * 200; //2_000_000 * 1e18;
        rebalanceToClose(false, liquidity, tokensHeld0, tokensHeld1, reserve0, reserve1, precision, expected, 9);
    }

    function testRebalanceToCloseFixed() public {
        fee1 = 1000;
        fee2 = 1000;
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 18;

        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        uint128 liquidity = uint128(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1));

        uint256 testCases = 5;
        uint128[] memory expected = new uint128[](2*testCases);
        expected[0] = 0;
        expected[1] = 0;
        expected[2] = 0;
        expected[3] = 863535466989341028068428;
        expected[4] = 1710056720322159396276892;
        expected[5] = 1;
        expected[6] = 1;
        expected[7] = 171005672032215939627685626;
        expected[8] = 8635354669893410280684;
        expected[9] = 7;
        rebalanceToCloseCasesByReserves(liquidity, tokensHeld0, tokensHeld1, 1e1, expected);
    }

    function testRebalanceToCloseFixed6x18() public {
        fee1 = 1000;
        fee2 = 1000;
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 6;
        decimals[1] = 18;

        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        uint128 liquidity = uint128(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1));

        uint256 testCases = 5;
        uint128[] memory expected = new uint128[](2*testCases);
        expected[0] = 0;
        expected[1] = 0;
        expected[2] = 0;
        expected[3] = 863535466989525327602744;
        expected[4] = 1710056720322;
        expected[5] = 101714868;
        expected[6] = 1;
        expected[7] = 171005672028974408121487366;
        expected[8] = 8635354670;
        expected[9] = 3600288244462;

        rebalanceToCloseCasesByReserves(liquidity, tokensHeld0, tokensHeld1, 1e13, expected);
    }

    function testRebalanceToCloseFixed18x6() public {
        fee1 = 1000;
        fee2 = 1000;
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 6;

        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        uint128 liquidity = uint128(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1));

        uint256 testCases = 5;
        uint128[] memory expected = new uint128[](2*testCases);
        expected[0] = 0;
        expected[1] = 0;
        expected[2] = 693960017;
        expected[3] = 863535466989;
        expected[4] = 1710056720321180146563676;
        expected[5] = 1;
        expected[6] = 8726;
        expected[7] = 171005672032216;
        expected[8] = 8635354669893449635319;
        expected[9] = 0;

        rebalanceToCloseCasesByReserves(liquidity, tokensHeld0, tokensHeld1, 1e9, expected);
    }

    function testRebalanceToCloseFixedWithFees() public {
        //fee1 = 1000;
        //fee2 = 1000;
        uint8[] memory decimals = new uint8[](2);
        decimals[0] = 18;
        decimals[1] = 18;

        uint128 tokensHeld0 = uint128(10_000 * (10**decimals[0])); // 100
        uint128 tokensHeld1 = uint128(1_000_000 * (10**decimals[1])); // 10_000

        uint128 liquidity = uint128(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1));

        uint256 testCases = 5;
        uint128[] memory expected = new uint128[](2*testCases);
        expected[0] = 0;
        expected[1] = 0;
        expected[2] = 139622094965630897;
        expected[3] = 863337681762232596378615;
        expected[4] = 1704584898593626638353145;
        expected[5] = 984970494266885971;
        expected[6] = 9849704942668860;
        expected[7] = 170458489859362663835310921;
        expected[8] = 8633376817622325963786;
        expected[9] = 13962209496563089647;
        rebalanceToCloseCasesByReserves(liquidity, tokensHeld0, tokensHeld1, 1e20, expected);
    }

    function testRebalanceToClose() public {
        uint112 _reserve0 = 0;
        uint112 _reserve1 = 0;
        uint8 borrow = 0;
        uint8 move = 165;
        bool side = true;

        fee1 = 1000;
        fee2 = 1000;

        if(move < 128) move = 128;

        (uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) =
            createMarketPosition2(_reserve0, _reserve1, borrow, move, side, 1e16);

        uint128 liquidity = uint128(GSMath.sqrt(uint256(tokensHeld0) * tokensHeld1));

        rebalanceToClose(false, liquidity, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e8, new uint128[](0), 0);
        rebalanceToClose(true, liquidity, tokensHeld0, tokensHeld1, reserve0, reserve1, 1e8, new uint128[](0), 0);
    }
}
