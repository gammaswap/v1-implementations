// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@gammaswap/v1-core/contracts/interfaces/strategies/base/ILiquidationStrategy.sol";
import "./BaseLongStrategy.sol";
import "../../libraries/Math.sol";
import "hardhat/console.sol";

abstract contract LiquidationStrategy is ILiquidationStrategy, BaseLongStrategy {

    error NoLiquidityProvided();
    error NotFullLiquidation();
    error HasMargin();

    function _liquidate(uint256 tokenId, int256[] calldata deltas) external override lock virtual returns(uint256[] memory refund) {
        (LibStorage.Loan storage _loan, uint256 loanLiquidity, ) = getLoanLiquidityAndCollateral(tokenId);

        uint128[] memory tokensHeld = rebalanceAndDepositCollateral(_loan, loanLiquidity, deltas);

        (tokensHeld, refund, loanLiquidity) = payLoanAndRefundLiquidator(tokenId, tokensHeld, loanLiquidity, 0, true);
        _loan.tokensHeld = tokensHeld;

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0);
    }

    function _liquidateWithLP(uint256 tokenId) external override lock virtual returns(uint256[] memory refund) {
        (LibStorage.Loan storage _loan, uint256 loanLiquidity, uint128[] memory tokensHeld) = getLoanLiquidityAndCollateral(tokenId);

        (tokensHeld, refund, loanLiquidity) = payLoanAndRefundLiquidator(tokenId, tokensHeld, loanLiquidity, 0, false);
        _loan.tokensHeld = tokensHeld;

        emit LoanUpdated(tokenId, tokensHeld, loanLiquidity, _loan.lpTokens, _loan.rateIndex);
    }

    function _batchLiquidations(uint256[] calldata tokenIds) external override lock virtual returns(uint256[] memory refund) {
        (uint256 loanLiquidity, uint256 collateral, uint256 lpTokenPrincipalPaid, uint128[] memory tokensHeld) = sumLiquidity(tokenIds);

        loanLiquidity = writeDown(0, collateral * 975 / 1000, loanLiquidity);

        (, refund,) = payLoanAndRefundLiquidator(0, tokensHeld, loanLiquidity, lpTokenPrincipalPaid, true);
    }

    function getLoanLiquidityAndCollateral(uint256 tokenId) internal virtual returns(LibStorage.Loan storage _loan, uint256 loanLiquidity, uint128[] memory tokensHeld) {
        _loan = s.loans[tokenId];

        loanLiquidity = updateLoan(_loan);

        tokensHeld = _loan.tokensHeld;

        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);

        canLiquidate(collateral, loanLiquidity, 950);

        loanLiquidity = writeDown(tokenId, collateral * 975 / 1000, loanLiquidity);
    }

    function payLoanAndRefundLiquidator(uint256 tokenId, uint128[] memory tokensHeld, uint256 loanLiquidity, uint256 lpTokenPrincipalPaid, bool isFullPayment)
        internal virtual returns(uint128[] memory, uint256[] memory, uint256) {

        uint256 payLiquidity;
        uint256 currLpBalance = s.LP_TOKEN_BALANCE;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;

        {
            uint256 lpDeposit = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this)) - currLpBalance;

            if(lpDeposit == 0) {
                revert NoLiquidityProvided();
            }

            (payLiquidity, lpDeposit) = refundOverPayment(loanLiquidity, lpDeposit, lastCFMMTotalSupply, lastCFMMInvariant); // full payment, TODO: Trick is here, this has to return another variable to multiply with the collateral

            currLpBalance = currLpBalance + lpDeposit;
        }

        if(isFullPayment && payLiquidity < loanLiquidity) {//only allow full liquidation, otherwise rebalancing of tokens can be done to worsen the LTV ratio, this check also works as slippage protection
            revert NotFullLiquidation();
        }

        uint256[] memory refund;
        (tokensHeld, refund) = refundLiquidator(payLiquidity, loanLiquidity, tokensHeld);

        {
            if(tokenId > 0) {
                LibStorage.Loan storage _loan = s.loans[tokenId];
                (lpTokenPrincipalPaid, loanLiquidity) = payLoanLiquidity(payLiquidity, loanLiquidity, _loan);
            }

            payPoolDebt(payLiquidity, lpTokenPrincipalPaid, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance, currLpBalance - s.LP_TOKEN_BALANCE);
        }

        emit PoolUpdated(currLpBalance, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);

        return(tokensHeld, refund, loanLiquidity);
    }

    function refundLiquidator(uint256 payLiquidity, uint256 loanLiquidity, uint128[] memory tokensHeld) internal virtual returns(uint128[] memory, uint256[] memory) {
        address[] memory tokens = s.tokens;
        uint256[] memory refund = new uint256[](tokens.length);
        uint128 payAmt = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            payAmt = uint128(payLiquidity * tokensHeld[i] / loanLiquidity);
            s.TOKEN_BALANCE[i] = s.TOKEN_BALANCE[i] - payAmt;
            refund[i] = payAmt;
            tokensHeld[i] = tokensHeld[i] - payAmt;
            GammaSwapLibrary.safeTransfer(IERC20(tokens[i]), msg.sender, refund[i]);
        }
        return(tokensHeld, refund);
    }

    function canLiquidate(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual view {
        if(collateral * limit / 1000 >= liquidity) {
            revert HasMargin();
        }
    }

    function refundOverPayment(uint256 loanLiquidity, uint256 lpDeposit, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) internal virtual returns(uint256, uint256) {
        uint256 payLiquidity = lpDeposit * lastCFMMInvariant / lastCFMMTotalSupply;
        if(payLiquidity <= loanLiquidity) {
            return(payLiquidity, lpDeposit);
        }
        // full payment
        uint256 invReturn;
        unchecked {
            invReturn = payLiquidity - loanLiquidity;
        }
        uint256 lpReturn = invReturn * lastCFMMTotalSupply / lastCFMMInvariant;
        GammaSwapLibrary.safeTransfer(IERC20(s.cfmm), msg.sender, lpReturn);

        return(loanLiquidity, lpDeposit - lpReturn);
    }

    function writeDown(uint256 tokenId, uint256 payableLiquidity, uint256 loanLiquidity) internal virtual returns(uint256) {
        if(payableLiquidity >= loanLiquidity) {
            return loanLiquidity;
        }
        uint256 writeDownAmt;
        unchecked{
            writeDownAmt = loanLiquidity - payableLiquidity;
        }
        // write down pool here
        uint128 borrowedInvariant = s.BORROWED_INVARIANT;
        borrowedInvariant = borrowedInvariant - uint128(writeDownAmt); // won'toverflow because borrowedInvariant is going down to at least the invariant in collateral units
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = calcLPTokenBorrowedPlusInterest(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        s.BORROWED_INVARIANT = borrowedInvariant;

        emit WriteDown(tokenId, writeDownAmt);

        return payableLiquidity;
    }

    function sumLiquidity(uint256[] calldata tokenIds) internal virtual returns(uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] memory tokensHeldTotal) {
        address[] memory tokens = s.tokens;
        uint128[] memory tokensHeld;
        address cfmm = s.cfmm;
        tokensHeldTotal = new uint128[](tokens.length);
        (uint256 accFeeIndex,,) = updateIndex();
        for(uint256 i = 0; i < tokenIds.length; i++) {
            LibStorage.Loan storage _loan = s.loans[tokenIds[i]];
            uint256 liquidity = uint128((_loan.liquidity * accFeeIndex) / _loan.rateIndex);
            tokensHeld = _loan.tokensHeld;
            lpTokensPrincipalTotal = lpTokensPrincipalTotal + _loan.lpTokens;
            _loan.liquidity = 0;
            _loan.initLiquidity = 0;
            _loan.rateIndex = 0;
            _loan.lpTokens = 0;
            uint256 collateral = calcInvariant(cfmm, tokensHeld);
            canLiquidate(collateral, liquidity, 950);
            collateralTotal = collateralTotal + collateral;
            liquidityTotal = liquidityTotal + liquidity;
            for(uint256 j = 0; j < tokens.length; j++) {
                tokensHeldTotal[j] = tokensHeldTotal[j] + tokensHeld[j];
                _loan.tokensHeld[j] = 0;
            }
        }

        emit BatchLiquidations(liquidityTotal, collateralTotal, lpTokensPrincipalTotal, tokensHeldTotal, tokenIds);
    }

    function rebalanceAndDepositCollateral(LibStorage.Loan storage _loan, uint256 loanLiquidity, int256[] calldata deltas) internal virtual returns(uint128[] memory tokensHeld){
        if(deltas.length > 0) {
            (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

            swapTokens(_loan, outAmts, inAmts);
        }
        updateCollateral(_loan);
        repayTokens(_loan, calcTokensToRepay(loanLiquidity));//SO real lptokens can be greater than we expected in repaying. Because real can go up untracked but can't go down untracked. So we might have repaid more than we expected even though we sent a smaller amount.
        tokensHeld = updateCollateral(_loan);// then update collateral
    }
}
