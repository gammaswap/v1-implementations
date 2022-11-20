// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/interfaces/strategies/base/ILongStrategy.sol";
import "./BaseStrategy.sol";

abstract contract LongStrategy is ILongStrategy, BaseStrategy {

    error Forbidden();
    error Margin();
    error NotEnoughBalance();
    error NotEnoughCollateral();
    error ExcessiveBorrowing();
    error NotEnoughLPDeposit();

    //LongGamma
    function beforeRepay(Loan storage _loan, uint256[] memory amounts) internal virtual;

    function calcTokensToRepay(uint256 liquidity)
        internal virtual view returns(uint256[] memory amounts);

    function beforeSwapTokens(Loan storage _loan, int256[] calldata deltas) internal virtual returns(uint256[] memory outAmts, uint256[] memory inAmts);

    function swapTokens(Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual;

    function originationFee() internal virtual view returns(uint16);

    function _getLoan(uint256 tokenId) internal virtual view returns(Loan storage _loan) {
        _loan = s.loans[tokenId];
        if(tokenId != uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id)))) {
            revert Forbidden();
        }
    }

    function checkMargin(Loan storage _loan, uint256 limit) internal virtual view {
        if(calcInvariant(s.cfmm, _loan.tokensHeld) * limit / 1000 < _loan.liquidity) {
            revert Margin();
        }
    }

    function sendToken(IERC20 token, address to, uint256 amount, uint256 balance, uint256 collateral) internal virtual {
        if(amount > balance){
            revert NotEnoughBalance();
        }
        if(amount > collateral){
            revert NotEnoughCollateral();
        }
        GammaSwapLibrary.safeTransfer(token, to, amount);
    }

    function sendTokens(Loan storage _loan, address to, uint256[] memory amounts) internal virtual {
        for (uint256 i = 0; i < s.tokens.length; i++) {
            if(amounts[i] > 0) {
                sendToken(IERC20(s.tokens[i]), to, amounts[i], s.TOKEN_BALANCE[i], _loan.tokensHeld[i]);
            }
        }
    }

    function repayTokens(Loan storage _loan, uint256[] memory amounts) internal virtual returns(uint256) {
        beforeRepay(_loan, amounts); // in balancer we do nothing here, in uni we send tokens here, definitely not going over since we check here that we have the collateral to send.
        return depositToCFMM(s.cfmm, amounts, address(this));//in balancer pulls tokens here and mints, in Uni it just mints)
    }

    function updateCollateral(Loan storage _loan) internal virtual {
        for (uint256 i = 0; i < s.tokens.length; i++) {
            uint256 currentBalance = GammaSwapLibrary.balanceOf(IERC20(s.tokens[i]), address(this));
            uint256 tokenBalance = s.TOKEN_BALANCE[i];
            uint256 tokenHeld = _loan.tokensHeld[i];
            if(currentBalance > tokenBalance) {
                uint256 balanceChange = currentBalance - tokenBalance;
                _loan.tokensHeld[i] = tokenHeld + balanceChange;
                s.TOKEN_BALANCE[i] = tokenBalance + balanceChange;
            } else if(currentBalance < tokenBalance) {
                uint256 balanceChange = tokenBalance - currentBalance;
                if(balanceChange > tokenBalance){
                    revert NotEnoughBalance();
                }
                if(balanceChange > tokenHeld){
                    revert NotEnoughCollateral();
                }
                unchecked {
                    _loan.tokensHeld[i] = tokenHeld - balanceChange;
                    s.TOKEN_BALANCE[i] = tokenBalance - balanceChange;
                }
            }
        }
    }

    function _increaseCollateral(uint256 tokenId) external virtual override lock returns(uint256[] memory) {
        Loan storage _loan = _getLoan(tokenId);
        updateCollateral(_loan);
        emit LoanUpdated(tokenId, _loan.tokensHeld, 0, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
        return _loan.tokensHeld;
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override lock returns(uint256[] memory) {
        Loan storage _loan = _getLoan(tokenId);
        sendTokens(_loan, to, amounts);
        updateCollateral(_loan);
        updateLoan(_loan);
        checkMargin(_loan, 800);
        emit LoanUpdated(tokenId, _loan.tokensHeld, 0, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
        return _loan.tokensHeld;
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint256[] memory amounts) {
        if(lpTokens >= s.LP_TOKEN_BALANCE) {
            revert ExcessiveBorrowing();
        }

        Loan storage _loan = _getLoan(tokenId);
        updateLoan(_loan);

        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        updateCollateral(_loan);

        openLoan(_loan, lpTokens);

        checkMargin(_loan, 800);

        emit LoanUpdated(tokenId, _loan.tokensHeld, 0, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        Loan storage _loan = _getLoan(tokenId);

        updateLoan(_loan);

        liquidityPaid = liquidity > _loan.liquidity ? _loan.liquidity : liquidity;

        amounts = calcTokensToRepay(liquidityPaid);// Now this amounts will always be correct. The other way, the user might have sometimes paid more than he wanted to just to pay off the loan.

        repayTokens(_loan, amounts);//So real lptokens can be greater than we expected in repaying. Because real can go up untracked but can't go down untracked. So we might have repaid more than we expected even though we sent a smaller amount.

        // then update collateral
        updateCollateral(_loan);

        payLoan(_loan, liquidityPaid);

        emit LoanUpdated(tokenId, _loan.tokensHeld, 0, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint256[] memory) {
        Loan storage _loan = _getLoan(tokenId);

        updateLoan(_loan);

        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

        swapTokens(_loan, outAmts, inAmts);

        updateCollateral(_loan);

        checkMargin(_loan, 850);

        emit LoanUpdated(tokenId, _loan.tokensHeld, 0, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);

        return _loan.tokensHeld;
    }

    function openLoan(Loan storage _loan, uint256 lpTokens) internal virtual {
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 lpTokensPlusOrigFee = lpTokens + lpTokens * originationFee() / 10000;
        uint256 liquidityBorrowed = calcLPInvariant(lpTokensPlusOrigFee, lastCFMMInvariant, lastCFMMTotalSupply);// The liquidity it represented at that time
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + liquidityBorrowed;
        s.BORROWED_INVARIANT = borrowedInvariant;
        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED + lpTokens;

        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));// this can be greater than expected (accrues to LPs), but can't be less (it's withdrawal of LP_TOKENS)
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        uint256 lpInvariant = calcLPInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = lpInvariant;

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokensPlusOrigFee;
        //s.LP_TOKEN_TOTAL = lpTokenBalance + lpTokenBorrowedPlusInterest;
        //s.TOTAL_INVARIANT = lpInvariant + borrowedInvariant;

        _loan.liquidity = _loan.liquidity + liquidityBorrowed;
        _loan.initLiquidity = _loan.initLiquidity + liquidityBorrowed;
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    function payLoan(Loan storage _loan, uint256 liquidity) internal virtual {
        uint256 newLPBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));// so lp balance is supposed to be greater than before, no matter what since tokens were deposited into the CFMM
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE;
        if(newLPBalance <= lpTokenBalance) {// the change will always be positive, might be greater than expected, which means you paid more. If it's less it will be a small difference because of a fee
            revert NotEnoughLPDeposit();
        }
        uint256 lpTokenChange = newLPBalance - lpTokenBalance;
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 paidLiquidity = calcLPInvariant(lpTokenChange, lastCFMMInvariant, lastCFMMTotalSupply);
        liquidity = paidLiquidity < liquidity ? paidLiquidity : liquidity; // take the lowest, if actually paid less liquidity than expected. Only way is there was a transfer fee

        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        uint256 lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        uint256 lpTokenPaid = calcLPTokenBorrowedPlusInterest(liquidity, lpTokenBorrowedPlusInterest, borrowedInvariant);// TODO: What about when it's very very small amounts in denominator?
        uint256 lpTokenPrincipal = calcLPTokenBorrowedPlusInterest(liquidity, _loan.lpTokens, _loan.liquidity);
        uint256 liquidityPrincipal = calcLPTokenBorrowedPlusInterest(liquidity, _loan.initLiquidity, _loan.liquidity);

        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED - lpTokenPrincipal;
        borrowedInvariant = borrowedInvariant - liquidity; // won't overflow
        s.BORROWED_INVARIANT = borrowedInvariant;

        s.LP_TOKEN_BALANCE = newLPBalance;// this can be greater than expected (accrues to LPs), or less if there's a token transfer fee
        uint256 lpInvariant = calcLPInvariant(newLPBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = lpInvariant;

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokenBorrowedPlusInterest - lpTokenPaid; // won't overflow
        //s.LP_TOKEN_TOTAL = newLPBalance + lpTokenBorrowedPlusInterest;
        //s.TOTAL_INVARIANT = lpInvariant + borrowedInvariant;

        _loan.liquidity = _loan.liquidity - liquidity;
        _loan.initLiquidity = _loan.initLiquidity - liquidityPrincipal;
        _loan.lpTokens = _loan.lpTokens - lpTokenPrincipal;
    }
}
