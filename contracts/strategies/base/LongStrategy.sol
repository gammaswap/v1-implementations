// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/interfaces/strategies/base/ILongStrategy.sol";
import "./BaseLongStrategy.sol";

/// @title Long Strategy abstract contract implementation of ILongStrategy
/// @author Daniel D. Alcarraz
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that borrow and repay liquidity
abstract contract LongStrategy is ILongStrategy, BaseLongStrategy {

    error ExcessiveBorrowing();

    // LongGamma

    /// @dev See {BaseLongStrategy-checkMargin}.
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(!hasMargin(collateral, liquidity, ltvThreshold())) { // if collateral is below ltvThreshold revert transaction
            revert Margin();
        }
    }

    /// @notice Assumes that collateral tokens were already deposited but not accounted for
    /// @dev See {ILongStrategy-_increaseCollateral}.
    function _increaseCollateral(uint256 tokenId) external virtual override lock returns(uint128[] memory tokensHeld) {
        // get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // update loan collateral token amounts with tokens deposited in GammaPool
        tokensHeld = updateCollateral(_loan);

        // do not check for loan undercollateralization because adding collateral always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        return tokensHeld;
    }

    /// @dev See {ILongStrategy-_decreaseCollateral}.
    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override lock returns(uint128[] memory tokensHeld) {
        // get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // withdraw collateral tokens from loan
        sendTokens(_loan, to, amounts);

        // update loan collateral token amounts after withdrawal
        tokensHeld = updateCollateral(_loan);

        // update liquidity debt with accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // revert if collateral invariant is below threshold after withdrawal
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, loanLiquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);

        return tokensHeld;
    }

    /// @dev See {ILongStrategy-_borrowLiquidity}.
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint256[] memory amounts) {
        // revert if borrowing all CFMM LP tokens in pool
        if(lpTokens >= s.LP_TOKEN_BALANCE) {
            revert ExcessiveBorrowing();
        }

        // get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // withdraw reserve tokens from CFMM that lpTokens represent
        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        // add withdrawn tokens as part of loan collateral
        uint128[] memory tokensHeld = updateCollateral(_loan);

        // add liquidity debt to total pool debt and start tracking loan
        loanLiquidity = openLoan(_loan, lpTokens);

        // check that loan is not undercollateralized
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, loanLiquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }

    /// @dev See {ILongStrategy-_repayLiquidity}.
    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        // get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // cap liquidity repayment at total liquidity debt
        liquidityPaid = payLiquidity > loanLiquidity ? loanLiquidity : payLiquidity;

        // calculate reserve tokens that liquidity repayment represents
        amounts = calcTokensToRepay(liquidityPaid);

        // repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts);

        // update loan collateral after repayment
        uint128[] memory tokensHeld = updateCollateral(_loan);

        // subtract loan liquidity repaid from total liquidity debt in pool and loan
        loanLiquidity = payLoan(_loan, liquidityPaid, loanLiquidity);

        // do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, loanLiquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }

    /// @dev See {ILongStrategy-_rebalanceCollateral}.
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint128[] memory tokensHeld) {
        // get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // calculate amounts to swap from deltas and available loan collateral
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

        // swap tokens
        swapTokens(_loan, outAmts, inAmts);

        // update loan collateral tokens after swap
        tokensHeld = updateCollateral(_loan);

        // check that loan is not undercollateralized after swap
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, loanLiquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }
}
