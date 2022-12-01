// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./BaseStrategy.sol";

abstract contract BaseLongStrategy is BaseStrategy {

    error Forbidden();
    error Margin();

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual;

    function calcTokensToRepay(uint256 liquidity) internal virtual view returns(uint256[] memory amounts);

    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual returns(uint256[] memory outAmts, uint256[] memory inAmts);

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual;

    function originationFee() internal virtual view returns(uint16);

    function _getLoan(uint256 tokenId) internal virtual view returns(LibStorage.Loan storage _loan) {
        _loan = s.loans[tokenId];
        if(tokenId != uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id)))) {
            revert Forbidden();
        }
    }

    function checkMargin(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual view {
        if(collateral * limit / 1000 < liquidity) {
            revert Margin();
        }
    }

    function sendTokens(LibStorage.Loan storage _loan, address to, uint256[] memory amounts) internal virtual {
        address[] memory tokens = s.tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            if(amounts[i] > 0) {
                sendToken(IERC20(tokens[i]), to, amounts[i], s.TOKEN_BALANCE[i], _loan.tokensHeld[i]);
            }
        }
    }

    function repayTokens(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual returns(uint256) {
        beforeRepay(_loan, amounts); // in balancer we do nothing here, in uni we send tokens here, definitely not going over since we check here that we have the collateral to send.
        return depositToCFMM(s.cfmm, amounts, address(this));//in balancer pulls tokens here and mints, in Uni it just mints)
    }

    function openLoan(LibStorage.Loan storage _loan, uint256 lpTokens) internal virtual returns(uint256 liquidity){
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 lpTokensPlusOrigFee = lpTokens + lpTokens * originationFee() / 10000;
        uint256 liquidityBorrowed = calcLPInvariant(lpTokensPlusOrigFee, lastCFMMInvariant, lastCFMMTotalSupply);// The liquidity it represented at that time
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + liquidityBorrowed;
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED + lpTokens;

        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));// this can be greater than expected (accrues to LPs), but can't be less (it's withdrawal of LP_TOKENS)
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        uint256 lpInvariant = calcLPInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokensPlusOrigFee;
        //s.LP_TOKEN_TOTAL = lpTokenBalance + lpTokenBorrowedPlusInterest;
        //s.TOTAL_INVARIANT = lpInvariant + borrowedInvariant;

        liquidity = _loan.liquidity + liquidityBorrowed;
        _loan.initLiquidity = _loan.initLiquidity + uint128(liquidityBorrowed);
        _loan.lpTokens = _loan.lpTokens + lpTokens;
        _loan.liquidity = uint128(liquidity);
    }

    function getLpTokenBalance() internal virtual returns(uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 paidLiquidity, uint256 newLPBalance) {
        newLPBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));// so lp balance is supposed to be greater than before, no matter what since tokens were deposited into the CFMM
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE;
        if(newLPBalance <= lpTokenBalance) {// the change will always be positive, might be greater than expected, which means you paid more. If it's less it will be a small difference because of a fee
            revert NotEnoughLPDeposit();
        }
        uint256 lpTokenChange = newLPBalance - lpTokenBalance;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        paidLiquidity = calcLPInvariant(lpTokenChange, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    function payLoan(LibStorage.Loan storage _loan, uint256 liquidity, uint256 loanLiquidity) internal virtual returns(uint256 remainingLiquidity) {
        (uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 paidLiquidity, uint256 newLPBalance) = getLpTokenBalance();
        liquidity = paidLiquidity < liquidity ? paidLiquidity : liquidity; // take the lowest, if actually paid less liquidity than expected. Only way is there was a transfer fee

        uint256 lpTokenPrincipal;
        (lpTokenPrincipal, remainingLiquidity) = payLoanLiquidity(liquidity, loanLiquidity, _loan);

        payPoolDebt(liquidity, lpTokenPrincipal, lastCFMMInvariant, lastCFMMTotalSupply, newLPBalance);
    }

    function payPoolDebt(uint256 liquidity, uint256 lpTokenPrincipal, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 newLPBalance) internal virtual {
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

    function payLoanLiquidity(uint256 liquidity, uint256 loanLiquidity, LibStorage.Loan storage _loan) internal virtual
        returns(uint256 lpTokenPrincipal, uint256 remainingLiquidity) {
        uint256 loanLpTokens = _loan.lpTokens;
        uint256 loanInitLiquidity = _loan.initLiquidity;
        lpTokenPrincipal = calcLPTokenBorrowedPlusInterest(liquidity, loanLpTokens, loanLiquidity);
        _loan.initLiquidity = uint128(loanInitLiquidity - calcLPTokenBorrowedPlusInterest(liquidity, loanInitLiquidity, loanLiquidity));
        _loan.lpTokens = loanLpTokens - lpTokenPrincipal;
        remainingLiquidity = loanLiquidity - liquidity;
        _loan.liquidity = uint128(remainingLiquidity);
        if(remainingLiquidity == 0) {
            _loan.rateIndex = 0;
        }
    }

    function sendToken(IERC20 token, address to, uint256 amount, uint256 balance, uint256 collateral) internal {
        if(amount > balance){
            revert NotEnoughBalance();
        }
        if(amount > collateral){
            revert NotEnoughCollateral();
        }
        GammaSwapLibrary.safeTransfer(token, to, amount);
    }

    function updateCollateral(LibStorage.Loan storage _loan) internal returns(uint128[] memory tokensHeld){
        address[] memory tokens = s.tokens;
        uint256 len = tokens.length;
        uint128[] memory tokenBalance = s.TOKEN_BALANCE;
        tokensHeld = _loan.tokensHeld;
        for (uint256 i = 0; i < len; i++) {
            uint256 currentBalance = GammaSwapLibrary.balanceOf(IERC20(tokens[i]), address(this));
            if(currentBalance > tokenBalance[i]) {
                uint128 balanceChange = uint128(currentBalance - tokenBalance[i]);
                tokensHeld[i] = tokensHeld[i] + balanceChange;
                tokenBalance[i] = tokenBalance[i] + balanceChange;
            } else if(currentBalance < tokenBalance[i]) {
                uint128 balanceChange = uint128(tokenBalance[i] - currentBalance);
                if(balanceChange > tokenBalance[i]){
                    revert NotEnoughBalance();
                }
                if(balanceChange > tokensHeld[i]){
                    revert NotEnoughCollateral();
                }
            unchecked {
                tokensHeld[i] = tokensHeld[i] - balanceChange;
                tokenBalance[i] = tokenBalance[i] - balanceChange;
            }
            }
        }
        _loan.tokensHeld = tokensHeld;
        s.TOKEN_BALANCE = tokenBalance;
    }
}
