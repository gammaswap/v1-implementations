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
    function beforeRepay(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory amounts) internal virtual;

    function calcTokensToRepay(GammaPoolStorage.Store storage store, uint256 liquidity)
        internal virtual view returns(uint256[] memory amounts);

    function beforeSwapTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, int256[] calldata deltas) internal virtual returns(uint256[] memory outAmts, uint256[] memory inAmts);

    function swapTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual;

    function getLoan(GammaPoolStorage.Store storage store, uint256 tokenId) internal virtual view returns(GammaPoolStorage.Loan storage _loan) {
        _loan = store.loans[tokenId];
        if(tokenId != uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id)))) {
            revert Forbidden();
        }
    }

    function checkMargin(GammaPoolStorage.Loan storage _loan, uint24 limit) internal virtual view {
        if(_loan.heldLiquidity * limit / 1000 < _loan.liquidity) {
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

    function sendTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, address to, uint256[] memory amounts) internal virtual {
        for (uint256 i = 0; i < store.tokens.length; i++) {
            if(amounts[i] > 0) {
                sendToken(IERC20(store.tokens[i]), to, amounts[i], store.TOKEN_BALANCE[i], _loan.tokensHeld[i]);
            }
        }
    }

    function repayTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory amounts) internal virtual returns(uint256) {
        beforeRepay(store, _loan, amounts); // in balancer we do nothing here, in uni we send tokens here, definitely not going over since we check here that we have the collateral to send.
        return depositToCFMM(store.cfmm, amounts, address(this));//in balancer pulls tokens here and mints, in Uni it just mints)
    }

    // TODO: Should check expected minAmounts. In case token has some type fee structure. If you are better off, allow it, good for you
    function updateCollateral(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal virtual {
        for (uint256 i = 0; i < store.tokens.length; i++) {
            uint256 currentBalance = GammaSwapLibrary.balanceOf(IERC20(store.tokens[i]), address(this));
            uint256 tokenBalance = store.TOKEN_BALANCE[i];
            uint256 tokenHeld = _loan.tokensHeld[i];
            if(currentBalance > tokenBalance) {
                uint256 balanceChange = currentBalance - tokenBalance;
                _loan.tokensHeld[i] = tokenHeld + balanceChange;
                store.TOKEN_BALANCE[i] = tokenBalance + balanceChange;
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
                    store.TOKEN_BALANCE[i] = tokenBalance - balanceChange;
                }
            }
        }
        _loan.heldLiquidity = calcInvariant(store.cfmm, _loan.tokensHeld);
    }

    // TODO: Should pass expected minAmts
    function _increaseCollateral(uint256 tokenId) external virtual override lock returns(uint256[] memory) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        updateCollateral(store, _loan);
        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
        return _loan.tokensHeld;
    }

    // TODO: Should pass expected minAmts
    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override lock returns(uint256[] memory) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        sendTokens(store, _loan, to, amounts);
        updateCollateral(store, _loan);
        updateLoan(store, _loan);
        checkMargin(_loan, 800);
        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
        return _loan.tokensHeld;
    }

    // TODO: Should pass expected minAmts for the withdrawal, prevent front running
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        if(lpTokens >= store.LP_TOKEN_BALANCE) {// TODO: Must add reserve check of 5% - 20%?
            revert ExcessiveBorrowing();
        }

        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        updateLoan(store, _loan);

        amounts = withdrawFromCFMM(store.cfmm, address(this), lpTokens);

        updateCollateral(store, _loan);// TODO: Must check that you received at least the min collateral you expected to receive, but ok to receive more.

        openLoan(store, _loan, lpTokens);

        checkMargin(_loan, 800);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    // TODO: Should pass expected minAmts for the deposit, prevent front running
    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store, _loan);

        liquidityPaid = liquidity > _loan.liquidity ? _loan.liquidity : liquidity;

        amounts = calcTokensToRepay(store, liquidityPaid);// Now this amounts will always be correct. The other way, the user might have sometimes paid more than he wanted to just to pay off the loan.

        repayTokens(store, _loan, amounts);//SO real lptokens can be greater than we expected in repaying. Because real can go up untracked but can't go down untracked. So we might have repaid more than we expected even though we sent a smaller amount.

        // then update collateral
        updateCollateral(store, _loan);// TODO: check that you got the min amount you expected. You might send less amounts than you expected. Which is good for you. It's only bad if sent out more, that's where slippage protection comes in.

        payLoan(store, _loan, liquidityPaid);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    // TODO: Should pass expected minAmts for the swap, prevent front running
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint256[] memory) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);

        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(store, _loan, deltas);

        swapTokens(store, _loan, outAmts, inAmts);

        updateCollateral(store, _loan);

        checkMargin(_loan, 850);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);

        return _loan.tokensHeld;
    }

    function openLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 lpTokens) internal virtual {
        uint256 lastCFMMInvariant = store.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = store.lastCFMMTotalSupply;
        uint256 liquidityBorrowed = calcLPInvariant(lpTokens, lastCFMMInvariant, lastCFMMTotalSupply);// The liquidity it represented at that time
        uint256 borrowedInvariant = store.BORROWED_INVARIANT + liquidityBorrowed;
        store.BORROWED_INVARIANT = borrowedInvariant;
        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED + lpTokens;

        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(store.cfmm), address(this));// this can be greater than expected (accrues to LPs), but can't be less (it's withdrawal of LP_TOKENS)
        store.LP_TOKEN_BALANCE = lpTokenBalance;
        uint256 lpInvariant = calcLPInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        store.LP_INVARIANT = lpInvariant;

        uint256 lpTokenBorrowedPlusInterest = store.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokens;
        store.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokenBorrowedPlusInterest;
        //store.LP_TOKEN_TOTAL = lpTokenBalance + lpTokenBorrowedPlusInterest;
        //store.TOTAL_INVARIANT = lpInvariant + borrowedInvariant;

        _loan.liquidity = _loan.liquidity + liquidityBorrowed;
        _loan.initLiquidity = _loan.initLiquidity + liquidityBorrowed;
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    function payLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 liquidity) internal virtual {
        uint256 newLPBalance = GammaSwapLibrary.balanceOf(IERC20(store.cfmm), address(this));// so lp balance is supposed to be greater than before, no matter what since tokens were deposited into the CFMM
        uint256 lpTokenBalance = store.LP_TOKEN_BALANCE;
        if(newLPBalance <= lpTokenBalance) {// the change will always be positive, might be greater than expected, which means you paid more. If it's less it will be a small difference because of a fee
            revert NotEnoughLPDeposit();
        }
        uint256 lpTokenChange = newLPBalance - lpTokenBalance;
        uint256 lastCFMMInvariant = store.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = store.lastCFMMTotalSupply;
        uint256 paidLiquidity = calcLPInvariant(lpTokenChange, lastCFMMInvariant, lastCFMMTotalSupply);
        liquidity = paidLiquidity < liquidity ? paidLiquidity : liquidity; // take the lowest, if actually paid less liquidity than expected. Only way is there was a transfer fee

        uint256 borrowedInvariant = store.BORROWED_INVARIANT;
        uint256 lpTokenBorrowedPlusInterest = store.LP_TOKEN_BORROWED_PLUS_INTEREST;
        uint256 lpTokenPaid = calcLPTokenBorrowedPlusInterest(liquidity, lpTokenBorrowedPlusInterest, borrowedInvariant);// TODO: What about when it's very very small amounts in denominator?
        uint256 lpTokenPrincipal = calcLPTokenBorrowedPlusInterest(liquidity, _loan.lpTokens, _loan.liquidity);
        uint256 liquidityPrincipal = calcLPTokenBorrowedPlusInterest(liquidity, _loan.initLiquidity, _loan.liquidity);

        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED - lpTokenPrincipal;
        borrowedInvariant = borrowedInvariant - liquidity;
        store.BORROWED_INVARIANT = borrowedInvariant; // won't overflow

        store.LP_TOKEN_BALANCE = newLPBalance;// this can be greater than expected (accrues to LPs), or less if there's a token transfer fee
        uint256 lpInvariant = calcLPInvariant(newLPBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        store.LP_INVARIANT = lpInvariant;

        lpTokenBorrowedPlusInterest = lpTokenBorrowedPlusInterest - lpTokenPaid; // won't overflow
        store.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokenBorrowedPlusInterest;
        //store.LP_TOKEN_TOTAL = newLPBalance + lpTokenBorrowedPlusInterest;
        //store.TOTAL_INVARIANT = lpInvariant + borrowedInvariant;

        _loan.liquidity = _loan.liquidity - liquidity;
        _loan.initLiquidity = _loan.initLiquidity - liquidityPrincipal;
        _loan.lpTokens = _loan.lpTokens - lpTokenPrincipal;
    }
}
