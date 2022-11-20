// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./LongStrategy.sol";

abstract contract LiquidationStrategy is LongStrategy {

    error NotFullLiquidation();
    error HasMargin();

    function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override lock virtual returns(uint256[] memory refund) {
        Loan storage _loan = _getLoan(tokenId);

        updateLoan(_loan);
        canLiquidate(_loan, 900);

        if(isRebalance) {
            (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

            swapTokens(_loan, outAmts, inAmts);
        }

        updateCollateral(_loan);

        uint256[] memory amounts = calcTokensToRepay(_loan.liquidity);// Now this amounts will always be correct. The other way, the user might have sometimes paid more than he wanted to just to pay off the loan.

        repayTokens(_loan, amounts);//SO real lptokens can be greater than we expected in repaying. Because real can go up untracked but can't go down untracked. So we might have repaid more than we expected even though we sent a smaller amount.

        // then update collateral
        updateCollateral(_loan);// TODO: check that you got the min amount you expected. You might send less amounts than you expected. Which is good for you. It's only bad if sent out more, that's where slippage protection comes in.

        return payLoanAndRefundLiquidator(tokenId, _loan);
    }

    function _liquidateWithLP(uint256 tokenId) external override lock virtual returns(uint256[] memory refund) {
        Loan storage _loan = s.loans[tokenId];

        uint256 lpDeposit = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this)) - s.LP_TOKEN_BALANCE;

        updateLoan(_loan);
        canLiquidate(_loan, 900);

        uint256 invDeposit = lpDeposit * s.lastCFMMInvariant / s.lastCFMMTotalSupply;
        if(invDeposit < _loan.liquidity) {
            revert NotFullLiquidation();
        }

        uint256 invReturn = invDeposit - _loan.liquidity;
        if(invReturn > 0) {
            uint256 lpReturn = invReturn * s.lastCFMMTotalSupply / s.lastCFMMInvariant;
            GammaSwapLibrary.safeTransfer(IERC20(s.cfmm), msg.sender, lpReturn);
        }

        return payLoanAndRefundLiquidator(tokenId, _loan);
    }

    function payLoanAndRefundLiquidator(uint256 tokenId, Loan storage _loan) internal virtual returns(uint256[] memory refund) {
        refund = new uint256[](s.tokens.length);
        for (uint256 i = 0; i < s.tokens.length; i++) {
            uint256 tokensHeld = _loan.tokensHeld[i];
            s.TOKEN_BALANCE[i] = s.TOKEN_BALANCE[i] - tokensHeld;
            _loan.tokensHeld[i] = 0;
            refund[i] = tokensHeld;
            GammaSwapLibrary.safeTransfer(IERC20(s.tokens[i]), msg.sender, tokensHeld);
        }
        _loan.heldLiquidity = 0;
        payLoan(_loan, _loan.liquidity);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);

        return refund;
    }

    function canLiquidate(Loan storage _loan, uint24 limit) internal virtual {
        if(_loan.heldLiquidity * limit / 1000 >= _loan.liquidity) {
            revert HasMargin();
        }
    }
}
