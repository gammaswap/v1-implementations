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

        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 invDeposit = lpDeposit * lastCFMMInvariant / lastCFMMTotalSupply;
        if(invDeposit < payLiquidity) {
            revert NotFullLiquidation();
        }

        uint256 invReturn = invDeposit - payLiquidity;
        if(invReturn > 0) {
            uint256 lpReturn = invReturn * lastCFMMTotalSupply / lastCFMMInvariant;
            GammaSwapLibrary.safeTransfer(IERC20(s.cfmm), msg.sender, lpReturn);
        }

        return payLoanAndRefundLiquidator(tokenId, _loan, payLiquidity);
    }

    function batchLiquidations(uint256[] calldata tokenIds) external virtual returns(uint128[] memory) {
        LibStorage.Loan storage _loan;
        updateIndex();
        address cfmm = s.cfmm;
        address[] memory tokens = s.tokens;

        (uint256 liquidityTotal, uint256 payLiquidityTotal, uint256 lpTokensPrincipalTotal, uint128[] memory tokensHeldTotal) = sumLiquidity(tokenIds);

        uint256 lpDeposit = GammaSwapLibrary.balanceOf(IERC20(cfmm), address(this)) - s.LP_TOKEN_BALANCE;

        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 invDeposit = lpDeposit * lastCFMMInvariant / lastCFMMTotalSupply;
        if(invDeposit < payLiquidityTotal) {
            revert NotFullLiquidation();
        }

        uint256 invReturn = invDeposit - payLiquidityTotal;
        if(invReturn > 0) {
            uint256 lpReturn = invReturn * lastCFMMTotalSupply / lastCFMMInvariant;
            GammaSwapLibrary.safeTransfer(IERC20(cfmm), msg.sender, lpReturn);
        }

        return payBatchLoansAndRefundLiquidator(tokens, tokensHeldTotal, payLiquidityTotal, liquidityTotal, lpTokensPrincipalTotal);
    }

    function payBatchLoansAndRefundLiquidator(address[] memory tokens, uint128[] memory tokensHeldTotal,
        uint256 payLiquidityTotal, uint256 liquidityTotal, uint256 lpTokensPrincipalTotal) internal virtual returns(uint128[] memory){
        uint128[] memory tokenBalance = s.TOKEN_BALANCE;
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenBalance[i] = tokenBalance[i] - tokensHeldTotal[i];
            GammaSwapLibrary.safeTransfer(IERC20(tokens[i]), msg.sender, tokensHeldTotal[i]);
        }
        s.TOKEN_BALANCE = tokenBalance;

        if(payLiquidityTotal < liquidityTotal) {
            uint256 writeDownAmt = 0;
            unchecked {
                writeDownAmt = liquidityTotal - payLiquidityTotal;
            }
            liquidityTotal = writeDown(liquidityTotal, writeDownAmt);
        }
        payBatchLoans(liquidityTotal, lpTokensPrincipalTotal);
        return tokensHeldTotal;
    }/**/

    function payBatchLoans(uint256 liquidity, uint256 lpTokenPrincipal) internal virtual {
        (uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 paidLiquidity, uint256 newLPBalance) = getLpTokenBalance();
        liquidity = paidLiquidity < liquidity ? paidLiquidity : liquidity; // take the lowest, if actually paid less liquidity than expected. Only way is there was a transfer fee

        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        uint256 lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        uint256 lpTokenPaid = calcLPTokenBorrowedPlusInterest(liquidity, lpTokenBorrowedPlusInterest, borrowedInvariant);// TODO: What about when it's very very small amounts in denominator?

        borrowedInvariant = borrowedInvariant - liquidity; // won't overflow
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);

        s.LP_TOKEN_BALANCE = newLPBalance;// this can be greater than expected (accrues to LPs), or less if there's a token transfer fee
        uint256 lpInvariant = calcLPInvariant(newLPBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokenBorrowedPlusInterest - lpTokenPaid; // won't overflow
        //s.LP_TOKEN_TOTAL = newLPBalance + lpTokenBorrowedPlusInterest;
        //s.TOTAL_INVARIANT = lpInvariant + borrowedInvariant;/**/

        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED - lpTokenPrincipal;
    }

    function payLoanAndRefundLiquidator(uint256 tokenId, LibStorage.Loan storage _loan, uint256 payLiquidity) internal virtual returns(uint256[] memory refund) {
        address[] memory tokens = s.tokens;
        uint128[] memory tokensHeld = _loan.tokensHeld;
        uint128[] memory tokenBalance = s.TOKEN_BALANCE;
        refund = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenBalance[i] = tokenBalance[i] - tokensHeld[i];
            refund[i] = uint256(tokensHeld[i]);
            tokensHeld[i] = 0;
            GammaSwapLibrary.safeTransfer(IERC20(tokens[i]), msg.sender, refund[i]);
        }

        s.TOKEN_BALANCE = tokenBalance;
        _loan.tokensHeld = tokensHeld;

        uint256 liquidity = _loan.liquidity;
        if(payLiquidity < liquidity) {
            uint256 writeDownAmt = 0;
            unchecked {
                writeDownAmt = liquidity - payLiquidity;
            }
            liquidity = writeDown(liquidity, writeDownAmt);
            _loan.liquidity = uint128(liquidity);
        }
        payLoan(_loan, liquidity);

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

    function writeDown(uint256 liquidity, uint256 writeDownAmt) internal virtual returns(uint256 newLiquidity){
        uint128 borrowedInvariant = s.BORROWED_INVARIANT;
        borrowedInvariant = borrowedInvariant - uint128(writeDownAmt); // won'toverflow because borrowedInvariant is going down to at least the invariant in collateral units
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = calcLPTokenBorrowedPlusInterest(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        s.BORROWED_INVARIANT = borrowedInvariant;
        newLiquidity = liquidity - writeDownAmt;
    }

    function sumLiquidity(uint256[] calldata tokenIds) internal virtual
        returns(uint256 liquidityTotal, uint256 payLiquidityTotal, uint256 lpTokensPrincipalTotal, uint128[] memory tokensHeldTotal) {
        address[] memory tokens = s.tokens;
        uint128[] memory tokensHeld;
        uint256 accFeeIndex = s.accFeeIndex;
        uint256 collateralTotal = 0;
        address cfmm = s.cfmm;
        tokensHeldTotal = new uint128[](tokens.length);
        for(uint256 i = 0; i < tokenIds.length; i++) {
            LibStorage.Loan storage _loan = s.loans[tokenIds[i]];
            uint256 liquidity = uint128((_loan.liquidity * accFeeIndex) / _loan.rateIndex);
            tokensHeld = _loan.tokensHeld;
            lpTokensPrincipalTotal = lpTokensPrincipalTotal + _loan.lpTokens;
            _loan.poolId = address(0);
            _loan.liquidity = 0;
            _loan.initLiquidity = 0;
            _loan.rateIndex = 0;
            _loan.lpTokens = 0;
            uint256 collateral = calcInvariant(cfmm, tokensHeld);
            canLiquidate(collateral, liquidity, 950);
            collateralTotal = collateralTotal + collateral;
            liquidityTotal = liquidityTotal + liquidity;
            for(uint256 j = 0; j < tokens.length; j++) {
                tokensHeldTotal[i] = tokensHeldTotal[i] + tokensHeld[i];
                tokensHeld[i] = 0;
                _loan.tokensHeld[i] = 0;
            }
        }

        payLiquidityTotal = Math.min(collateralTotal * 975 / 1000, liquidityTotal);
    }

}
