pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../contracts/interfaces/math/ICPMMMath.sol";
import "../../contracts/libraries/cpmm/CPMMMath.sol";

contract CalcDeltasBase is Test {

    ICPMMMath mathLib;
    uint256 fee1 = 997;
    uint256 fee2 = 1000;

    function setUp() public {
        mathLib = new CPMMMath();
    }

    function calcSellQty(uint256 reserve0, uint256 reserve1, uint256 amount0) internal view returns(uint256) {
        return (reserve1 * amount0 * fee2 / ((reserve0 - amount0) * fee1)) + 1;
    }

    function calcBuyQty(uint256 reserve0, uint256 reserve1, uint256 amount0) internal view returns(uint256) {
        return reserve1 * amount0 * fee1 / (reserve0 * fee2 + amount0*fee1);
    }

    function calcPercentAmt(uint256 reserve, uint256 borrow, uint256 denom) internal view returns(uint256) {
        return reserve * borrow / GSMath.max(borrow, denom);
    }

    function updateTokenQtys(uint128 tokensHeld0, uint128 tokensHeld1, uint128 reserve0, uint128 reserve1,
        int256 deltas0, int256 deltas1) internal view returns(uint128, uint128, uint128, uint128) {
        if(deltas0 > 0) {
            uint256 soldToken = calcSellQty(reserve0, reserve1, uint256(deltas0));
            tokensHeld1 -= uint128(soldToken);
            tokensHeld0 += uint128(uint256(deltas0));
            reserve1 += uint128(soldToken);
            reserve0 -= uint128(uint256(deltas0));
        } else if(deltas1 > 0) {
            uint256 soldToken = calcSellQty(reserve1, reserve0, uint256(deltas1));
            tokensHeld0 -= uint128(soldToken);
            tokensHeld1 += uint128(uint256(deltas1));
            reserve0 += uint128(soldToken);
            reserve1 -= uint128(uint256(deltas1));
        } else if(deltas0 < 0) {
            uint256 boughtToken = calcBuyQty(reserve0, reserve1, uint256(-deltas0));
            tokensHeld1 += uint128(boughtToken);
            tokensHeld0 -= uint128(uint256(-deltas0));
            reserve1 -= uint128(boughtToken);
            reserve0 += uint128(uint256(-deltas0));
        } else if(deltas1 < 0) {
            uint256 boughtToken = calcBuyQty(reserve1, reserve0, uint256(-deltas1));
            tokensHeld0 += uint128(boughtToken);
            tokensHeld1 -= uint128(uint256(-deltas1));
            reserve0 -= uint128(boughtToken);
            reserve1 += uint128(uint256(-deltas1));
        }
        return(tokensHeld0, tokensHeld1, reserve0, reserve1);
    }

    function createRatioParameter(uint128 tokensHeld0, uint128 tokensHeld1, uint8 move) internal view
        returns(uint256[] memory ratio) {
        uint256 _move = uint256(move) * 1000 / 255;

        if(_move < 5) {
            _move = 5;
        }

        ratio = new uint256[](2);
        ratio[0] = tokensHeld0 * 100 / _move;
        ratio[1] = tokensHeld1 * _move / 100;
    }

    function updateInitTokenQtys(uint8 move, bool side, uint128 reserve0, uint128 reserve1,
        uint128 tokensHeld0, uint128 tokensHeld1) internal virtual view returns(uint128, uint128, uint128, uint128) {

        if(move == 0) return(reserve0, reserve1, tokensHeld0, tokensHeld1);

        if(side) {
            uint256 sellAmt1 = calcPercentAmt(tokensHeld1, move, 500);
            uint256 buyAmt0 = calcBuyQty(reserve1, reserve0, sellAmt1);
            tokensHeld1 -= uint128(sellAmt1);
            tokensHeld0 += uint128(buyAmt0);
            reserve1 = reserve1 + uint128(sellAmt1);
            reserve0 = reserve0 - uint128(buyAmt0);
        } else {
            uint256 sellAmt0 = calcPercentAmt(tokensHeld0, move, 500);
            uint256 buyAmt1 = calcBuyQty(reserve0, reserve1, sellAmt0);
            tokensHeld0 -= uint128(sellAmt0);
            tokensHeld1 += uint128(buyAmt1);
            reserve0 += uint128(sellAmt0);
            reserve1 -= uint128(buyAmt1);
        }
        return(reserve0, reserve1, tokensHeld0, tokensHeld1);
    }

    function createMarketPosition(uint128 _reserve0, uint128 _reserve1, uint8 borrow, uint8 move, bool side) internal view
        returns(uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) {
        reserve0 = _reserve0;
        reserve1 = _reserve1;

        if(reserve0 < 1e6) reserve0 = 1e6;
        if(reserve1 < 1e6) reserve1 = 1e6;
        if(borrow < 128) borrow = 128;

        tokensHeld0 = uint128(calcPercentAmt(reserve0, borrow, 1000));
        tokensHeld1 = uint128(calcPercentAmt(reserve1, borrow, 1000));

        (reserve0, reserve1, tokensHeld0, tokensHeld1) = updateInitTokenQtys(move, side, reserve0, reserve1,
            tokensHeld0, tokensHeld1);
    }

    function createMarketPosition2(uint128 _reserve0, uint128 _reserve1, uint8 borrow, uint8 move, bool side, uint256 floor) internal view
        returns(uint128 reserve0, uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) {
        reserve0 = _reserve0;
        reserve1 = _reserve1;

        if(reserve0 < floor) reserve0 = uint128(floor);
        if(reserve1 < floor) reserve1 = uint128(floor);
        if(borrow < 128) borrow = 128;

        uint256 ratio = reserve1 / reserve0;
        uint256 maxRatio = 1e8;
        if(ratio > maxRatio) {
            reserve1 = uint128(reserve0 * maxRatio);
        } else {
            ratio = reserve0 / reserve1;
            if(ratio > maxRatio) {
                reserve0 = uint128(reserve1 * maxRatio);
            }
        }

        tokensHeld0 = uint128(calcPercentAmt(reserve0, borrow, 1000));
        tokensHeld1 = uint128(calcPercentAmt(reserve1, borrow, 1000));

        (reserve0, reserve1, tokensHeld0, tokensHeld1) = updateInitTokenQtys(move, side, reserve0, reserve1,
            tokensHeld0, tokensHeld1);
    }
}
