// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@gammaswap/v1-core/contracts/interfaces/strategies/base/ILiquidationStrategy.sol";
import "./BaseLongStrategy.sol";
import "../../libraries/Math.sol";

abstract contract LiquidationStrategy is ILiquidationStrategy, BaseLongStrategy {

    error NotFullLiquidation();
    error HasMargin();

    function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override lock virtual returns(uint256[] memory refund) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        updateLoan(_loan);

        uint256 collateral = calcInvariant(s.cfmm, _loan.tokensHeld);
        uint256 liquidity = _loan.liquidity;

        canLiquidate(collateral, liquidity, 950);

        uint256 payLiquidity = Math.min(collateral * 975 / 1000, liquidity);

        if(isRebalance) {
            (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

            swapTokens(_loan, outAmts, inAmts);
        }

        updateCollateral(_loan);

        uint256[] memory amounts = calcTokensToRepay(payLiquidity);// Now this amounts will always be correct. The other way, the user might have sometimes paid more than he wanted to just to pay off the loan.

        repayTokens(_loan, amounts);//SO real lptokens can be greater than we expected in repaying. Because real can go up untracked but can't go down untracked. So we might have repaid more than we expected even though we sent a smaller amount.

        // then update collateral
        updateCollateral(_loan);// TODO: check that you got the min amount you expected. You might send less amounts than you expected. Which is good for you. It's only bad if sent out more, that's where slippage protection comes in.

        return payLoanAndRefundLiquidator(tokenId, _loan, payLiquidity);
    }

    function _liquidateWithLP(uint256 tokenId) external override lock virtual returns(uint256[] memory refund) {
        LibStorage.Loan storage _loan = s.loans[tokenId];

        uint256 lpDeposit = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this)) - s.LP_TOKEN_BALANCE;

        updateLoan(_loan);

        uint256 collateral = calcInvariant(s.cfmm, _loan.tokensHeld);
        uint256 liquidity = _loan.liquidity;

        canLiquidate(collateral, liquidity, 950);

        uint256 payLiquidity = Math.min(collateral * 975 / 1000, liquidity);

        uint256 invDeposit = lpDeposit * s.lastCFMMInvariant / s.lastCFMMTotalSupply;
        if(invDeposit < payLiquidity) {
            revert NotFullLiquidation();
        }

        uint256 invReturn = invDeposit - payLiquidity;
        if(invReturn > 0) {
            uint256 lpReturn = invReturn * s.lastCFMMTotalSupply / s.lastCFMMInvariant;
            GammaSwapLibrary.safeTransfer(IERC20(s.cfmm), msg.sender, lpReturn);
        }

        return payLoanAndRefundLiquidator(tokenId, _loan, payLiquidity);
    }

    function payLoanAndRefundLiquidator(uint256 tokenId, LibStorage.Loan storage _loan, uint256 payLiquidity) internal virtual returns(uint256[] memory refund) {
        refund = new uint256[](s.tokens.length);
        address[] memory tokens = s.tokens;
        uint128[] memory tokensHeld = _loan.tokensHeld;
        uint128[] memory tokenBalance = s.TOKEN_BALANCE;
        for (uint256 i = 0; i < s.tokens.length; i++) {
            tokenBalance[i] = tokenBalance[i] - tokensHeld[i];
            refund[i] = uint256(tokensHeld[i]);
            tokensHeld[i] = 0;
            GammaSwapLibrary.safeTransfer(IERC20(tokens[i]), msg.sender, refund[i]);
        }

        s.TOKEN_BALANCE = tokenBalance;
        _loan.tokensHeld = tokensHeld;

        uint256 liquidity = _loan.liquidity;
        payLoan(_loan, liquidity);

        if(payLiquidity < liquidity) {
            uint256 writeDownAmt = 0;
            unchecked {
                writeDownAmt = liquidity - payLiquidity;
            }
            writeDown(writeDownAmt);
        }

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);

        return refund;
    }

    function canLiquidate(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual {
        if(collateral * limit / 1000 >= liquidity) {
            revert HasMargin();
        }
    }

    function writeDown(uint256 payLiquidity) internal virtual {
        uint128 borrowedInvariant = s.BORROWED_INVARIANT;
        borrowedInvariant = borrowedInvariant - uint128(payLiquidity); // won'toverflow because borrowedInvariant is going down to at least the invariant in collateral units
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = calcLPTokenBorrowedPlusInterest(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        s.BORROWED_INVARIANT = borrowedInvariant;
    }

}
