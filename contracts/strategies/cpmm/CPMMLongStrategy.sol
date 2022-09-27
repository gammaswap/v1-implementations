// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../base/LongStrategy.sol";
import "./CPMMBaseStrategy.sol";

contract CPMMLongStrategy is CPMMBaseStrategy, LongStrategy {

    function convertLiquidityToAmounts(GammaPoolStorage.Store storage store, uint256 liquidity) internal view returns(uint256 amount0, uint256 amount1) {
        uint256 lastCFMMTotalSupply = store.lastCFMMTotalSupply;
        amount0 = liquidity * store.CFMM_RESERVES[0] / lastCFMMTotalSupply;
        amount1 = liquidity * store.CFMM_RESERVES[1] / lastCFMMTotalSupply;
    }

    function calcRepayAmounts(GammaPoolStorage.Store storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override
        returns(uint256[] memory _tokensHeld, uint256[] memory amounts) {
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = convertLiquidityToAmounts(store, liquidity);
        require(tokensHeld[0] >= amounts[0] && tokensHeld[1] >= amounts[1], "< amounts");

        address cfmm = store.cfmm;
        sendToken(store.tokens[0], cfmm, amounts[0]);
        sendToken(store.tokens[1], cfmm, amounts[1]);

        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] - amounts[0];
        _tokensHeld[1] = tokensHeld[1] - amounts[1];
    }

    function sendToken(address token, address to, uint256 amount) internal {
        if(amount > 0) GammaSwapLibrary.safeTransfer(token, to, amount);
    }

    function rebalancePosition(GammaPoolStorage.Store storage store, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld) {
        (uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) = rebalancePosition(store.CFMM_RESERVES[0], store.CFMM_RESERVES[1], deltas[0], deltas[1]);
        _tokensHeld = new uint256[](2);

        _tokensHeld[0] = tokensHeld[0] + inAmt0 - outAmt0;
        _tokensHeld[1] = tokensHeld[1] + inAmt1 - outAmt1;

        address cfmm = store.cfmm;
        sendToken(store.tokens[0], cfmm, outAmt0);
        sendToken(store.tokens[1], cfmm, outAmt1);
        ICPMM(cfmm).swap(inAmt0,inAmt1,address(this), new bytes(0));
    }

    function rebalancePosition(uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1) internal view returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        require((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0), "bad delta");
        if(delta0 > 0 || delta1 > 0) {
            inAmt0 = uint256(delta1);//buy token1
            if(delta0 > 0) (inAmt0, reserve0, reserve1) = (uint256(delta0), reserve1, reserve0);//buy token0
            outAmt0 = calcAmtOut(inAmt0, reserve0, reserve1);
            if(inAmt0 != uint256(delta0)) (inAmt1, inAmt0, outAmt0, outAmt1) = (inAmt0, inAmt1, outAmt1, outAmt0);
        } else {
            outAmt0 = uint256(-delta0);//sell token0
            if(delta1 < 0) (outAmt0, reserve0, reserve1) = (uint256(-delta1), reserve1, reserve0);//sell token1
            inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1);
            if(outAmt0 != uint256(-delta0)) (inAmt0, inAmt1, outAmt0, outAmt1) = (inAmt1, inAmt0, outAmt1, outAmt0);
        }
    }

    // selling exactly amountOut
    function calcAmtIn(uint256 amountOut, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        require(reserveOut > 0 && reserveIn > 0, "0 reserve");
        CPMMStrategyStorage.Store storage store = CPMMStrategyStorage.store();
        uint256 amountOutWithFee = amountOut * store.tradingFee2;
        uint256 denominator = (reserveOut * store.tradingFee1) + amountOutWithFee;
        return amountOutWithFee * reserveIn / denominator;
    }

    // buying exactly amountIn
    function calcAmtOut(uint256 amountIn, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        require(reserveOut > 0 && reserveIn > 0, "0 reserve");
        CPMMStrategyStorage.Store storage store = CPMMStrategyStorage.store();
        uint256 denominator = (reserveIn - amountIn) * store.tradingFee2;
        return (reserveOut * amountIn * store.tradingFee1 / denominator) + 1;
    }
}
