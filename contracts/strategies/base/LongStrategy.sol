// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/interfaces/strategies/base/ILongStrategy.sol";
import "./BaseLongStrategy.sol";

abstract contract LongStrategy is ILongStrategy, BaseLongStrategy {

    error ExcessiveBorrowing();

    //LongGamma

    function _increaseCollateral(uint256 tokenId) external virtual override lock returns(uint128[] memory tokensHeld) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        tokensHeld = updateCollateral(_loan);
        emit LoanUpdated(tokenId, tokensHeld, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
        return tokensHeld;
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override lock returns(uint128[] memory tokensHeld) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        sendTokens(_loan, to, amounts);
        tokensHeld = updateCollateral(_loan);
        uint256 liquidity = updateLoan(_loan);

        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, liquidity, 800);

        emit LoanUpdated(tokenId, tokensHeld, liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
        return tokensHeld;
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint256[] memory amounts) {
        if(lpTokens >= s.LP_TOKEN_BALANCE) {
            revert ExcessiveBorrowing();
        }

        LibStorage.Loan storage _loan = _getLoan(tokenId);
        uint256 liquidity = updateLoan(_loan);

        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        uint128[] memory tokensHeld = updateCollateral(_loan);

        liquidity = openLoan(_loan, lpTokens);

        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, liquidity, 800);

        emit LoanUpdated(tokenId, tokensHeld, liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }

    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        uint256 _liquidity = updateLoan(_loan);

        liquidityPaid = payLiquidity > _liquidity ? _liquidity : payLiquidity;

        amounts = calcTokensToRepay(liquidityPaid);// Now this amounts will always be correct. The other way, the user might have sometimes paid more than he wanted to just to pay off the loan.

        repayTokens(_loan, amounts);//So real lptokens can be greater than we expected in repaying. Because real can go up untracked but can't go down untracked. So we might have repaid more than we expected even though we sent a smaller amount.

        // then update collateral
        uint128[] memory tokensHeld = updateCollateral(_loan);

        payLoan(_loan, liquidityPaid);

        emit LoanUpdated(tokenId, tokensHeld, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint128[] memory tokensHeld) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        uint256 liquidity = updateLoan(_loan);

        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

        swapTokens(_loan, outAmts, inAmts);

        tokensHeld = updateCollateral(_loan);

        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, liquidity, 850);

        emit LoanUpdated(tokenId, tokensHeld, liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }
}
