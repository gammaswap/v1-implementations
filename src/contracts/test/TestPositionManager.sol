// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import '../PositionManager.sol';

contract TestPositionManager is PositionManager {

    event TestInfo(uint256 num1, uint256 num2, uint256 num3, uint256 num4, uint256 num5, uint256 num6, uint256 num7, uint256 num8, uint256 num9, uint256 num10);

    constructor(address _uniRouter) PositionManager(_uniRouter, "","") {
    }

    function forceUpdatePositionLiquidity(uint256 tokenId) public {
        Position storage position = _positions[tokenId];
        updatePositionLiquidity(position);
    }

    /*function testRefundAmountsToRecipient(uint256 tokenId, address recipient, RefundParams memory rParams) public {
        Position storage position = _positions[tokenId];
        refundAmountsToRecipient(position, recipient, rParams);
    }

    function testCalcPaymentsAndLiquidity(uint256 token0Amt, uint256 token1Amt, uint256 px) public view returns(uint256 payAmt0, uint256 payAmt1, uint256 payLiquidity) {
        (payAmt0, payAmt1, payLiquidity) = calcPaymentsAndLiquidity(token0Amt, token1Amt, px);
    }

    function testCalcRefundPct(uint256 heldBalance, uint256 owedBalance, uint256 origLiquidity, uint256 payLiquidity) public view returns(uint256 refundPct) {
        refundPct = calcRefundPct(heldBalance, owedBalance, origLiquidity, payLiquidity);
    }

    function testCalcShortfallPayments(uint256 heldBalance, uint256 owedBalance, uint256 payLiquidity, uint256 px) public view returns(uint256 payAmt0, uint256 payAmt1, uint256 shortfallLiquidity) {
        (payAmt0, payAmt1, shortfallLiquidity) = calcShortfallPayments(heldBalance, owedBalance, payLiquidity, px);
    }

    function testUpdateCollateralAndRefund(uint256 tokenId, uint256 refundPct, uint256 refundAmt0, uint256 refundAmt1) public returns(uint256 _refundAmt0, uint256 _refundAmt1, uint256 _refundAmtUniPair) {
        Position storage position = _positions[tokenId];
        (_refundAmt0, _refundAmt1, _refundAmtUniPair) = updateCollateralAndRefund(position, refundPct, refundAmt0, refundAmt1);
        position.liquidity = _refundAmt0;
        position.rateIndex = _refundAmt1;
        position.blockNum = _refundAmtUniPair;
    }

    function testCalculateMaxLiquidation(uint256 posLiquidity, uint256 owedBalance, uint256 heldBalance) public view returns(uint256 maxLiquidation) {
        maxLiquidation = calculateMaxLiquidation(posLiquidity, owedBalance, heldBalance);
    }

    function testCalculatePaymentsAndRefundsForUnderwater(uint256 tokenId, uint256 owedBalance, uint256 heldBalance) public returns(RefundParams memory r) {
        Position storage position = _positions[tokenId];
        updatePositionLiquidity(position);
        uint256 liquidity = position.liquidity;
        r = calculatePaymentsAndRefundsForUnderwater(position, owedBalance, heldBalance);
        emit TestInfo(r.payAmt0, r.payAmt1, r.shortfallLiquidity, r.refundAmt0, r.refundAmt1, r.refundAmtUniPair, liquidity, 0, 0, 0);
    }

    function testCalculateUniPaymentsAndRefunds(uint256 tokenId, uint256 owedBalance, uint256 heldBalance) public returns(RefundParams memory r) {
        Position storage position = _positions[tokenId];
        updatePositionLiquidity(position);
        uint256 liquidity = position.liquidity;
        uint256 maxLiquidation = calculateMaxLiquidation(liquidity, owedBalance, heldBalance);
        r = calculateUniPaymentsAndRefunds(position, owedBalance, heldBalance, maxLiquidation);
        emit TestInfo(r.payAmt0, r.payAmt1, r.payUniLiquidity, r.refundAmt0, r.refundAmt1, r.refundAmtUniPair, liquidity, r.maxLiquidation, r.payUniShares, 0);
    }

    function testCalculatePaymentsAndRefunds(uint256 tokenId, uint256 owedBalance, uint256 heldBalance) public returns(RefundParams memory r) {
        Position storage position = _positions[tokenId];
        updatePositionLiquidity(position);
        uint256 liquidity = position.liquidity;
        r = calculatePaymentsAndRefunds(position, owedBalance, heldBalance);
        emit TestInfo(r.payAmt0, r.payAmt1, r.payLiquidity, r.refundAmt0, r.refundAmt1, r.refundAmtUniPair, liquidity, r.maxLiquidation, r.payUniShares, r.payUniLiquidity);
    }/**/
}
