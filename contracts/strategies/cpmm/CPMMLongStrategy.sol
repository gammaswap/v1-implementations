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

    function calcRepayAmounts(GammaPoolStorage.Store storage store, uint256 liquidity) internal virtual override view
        returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = convertLiquidityToAmounts(store, liquidity);
    }

    function swapAmounts(GammaPoolStorage.Store storage store, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address cfmm = store.cfmm;
        sendAmounts(store, cfmm, outAmts, true);
        ICPMM(cfmm).swap(inAmts[0],inAmts[1],address(this),new bytes(0));
    }

    function sendAmounts(GammaPoolStorage.Store storage store, address to, uint256[] memory amounts, bool force) internal virtual override {// TODO: Should probably be changed to something else and a different one should be implemented
        sendToken(store.tokens[0], to, amounts[0]);
        sendToken(store.tokens[1], to, amounts[1]);
    }

    function sendToken(address token, address to, uint256 amount) internal { // TODO: probably needs to move upstream
        if(amount > 0) GammaSwapLibrary.safeTransfer(token, to, amount);
    }

    function calcDeltaAmounts(GammaPoolStorage.Store storage store, int256[] calldata deltas) internal virtual override view returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = rebalancePosition(store.CFMM_RESERVES[0], store.CFMM_RESERVES[1], deltas[0], deltas[1]); // TODO: Add slippage check
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
