// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@gammaswap/v1-core/contracts/interfaces/strategies/base/ILongStrategy.sol";
import "./BaseStrategy.sol";

abstract contract LongStrategy is ILongStrategy, BaseStrategy {

    //LongGamma
    function calcRepayAmounts(GammaPoolStorage.Store storage store, uint256 liquidity)
        internal virtual view returns(uint256[] memory amounts);

    function calcDeltaAmounts(GammaPoolStorage.Store storage store, int256[] calldata deltas) internal virtual view returns(uint256[] memory outAmts, uint256[] memory inAmts);

    function swapAmounts(GammaPoolStorage.Store storage store, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual;

    function getLoan(GammaPoolStorage.Store storage store, uint256 tokenId) internal virtual view returns(GammaPoolStorage.Loan storage _loan) {
        _loan = store.loans[tokenId];
        require(tokenId == uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id))), "FORBIDDEN");
    }

    function checkMargin(GammaPoolStorage.Loan storage _loan, uint24 limit) internal virtual view {
        require(_loan.heldLiquidity * limit / 1000 >= _loan.liquidity, "margin");
    }

    function sendAmounts(GammaPoolStorage.Store storage store, address to, uint256[] memory amounts) internal virtual {
        for (uint256 i = 0; i < store.tokens.length; i++) {
            if(amounts[i] > 0) {
                require(amounts[i] <= store.TOKEN_BALANCE[i], "> bal");
                GammaSwapLibrary.safeTransfer(store.tokens[i], to, amounts[i]);
            }
        }
    }

    function repayAmounts(GammaPoolStorage.Store storage store, address cfmm, uint256[] memory amounts) internal virtual returns(uint256 lpTokensPaid){
        preDepositToCFMM(store, amounts, address(this), new bytes(0)); // in balancer we do nothing here, in uni we send tokens here
        lpTokensPaid = depositToCFMM(store.cfmm, amounts, address(this));//in balancer pulls tokens here and mints, in Uni it just mints)
    }

    // TODO: Should check expected minAmounts. In case token has some type fee structure. If you are better off, allow it, good for you
    function updateCollateral(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal virtual {
        for (uint256 i = 0; i < store.tokens.length; i++) {
            uint256 currentBalance = GammaSwapLibrary.balanceOf(store.tokens[i], address(this));
            if(currentBalance > store.TOKEN_BALANCE[i]) {
                uint256 balanceChange = currentBalance - store.TOKEN_BALANCE[i];
                _loan.tokensHeld[i] = _loan.tokensHeld[i] + balanceChange;
                store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] + balanceChange;
            } else if(currentBalance < store.TOKEN_BALANCE[i]) {
                uint256 balanceChange = store.TOKEN_BALANCE[i] - currentBalance;
                require(_loan.tokensHeld[i] >= balanceChange, "> held");
                require(store.TOKEN_BALANCE[i] >= balanceChange, "> bal");
                unchecked{
                    _loan.tokensHeld[i] = _loan.tokensHeld[i] - balanceChange;
                    store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] - balanceChange;
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
        sendAmounts(store, to, amounts);
        updateCollateral(store, _loan);
        updateLoan(store, _loan);
        checkMargin(_loan, 800);
        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
        return _loan.tokensHeld;
    }

    function calcLPTokenChange(uint256 newLPTokenBalance, uint256 oldLPTokenBalance) internal virtual pure returns(uint256){
        if(newLPTokenBalance <  oldLPTokenBalance) {
            unchecked {
                return oldLPTokenBalance - newLPTokenBalance;
            }
        }
        return 0;
    }

    // TODO: Should pass expected minAmts for the withdrawal, prevent front running
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        require(lpTokens < store.LP_TOKEN_BALANCE, "> liq");// TODO: Must add reserve check of 5% - 20%?

        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        updateLoan(store, _loan);

        amounts = withdrawFromCFMM(store.cfmm, address(this), lpTokens);

        uint256 newLPTokenBalance = GammaSwapLibrary.balanceOf(store.cfmm, address(this));
        uint256 lpTokenChange = calcLPTokenChange(newLPTokenBalance, store.LP_TOKEN_BALANCE);

        require(lpTokenChange <= lpTokens, "> lpTokens");

        updateCollateral(store, _loan);// TODO: Must check that you received at least the min collateral you expected to receive

        openLoan(store, _loan, lpTokenChange);

        checkMargin(_loan, 800);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
    }

    // TODO: Should pass expected minAmts for the deposit, prevent front running
    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override lock returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store, _loan);

        amounts = calcRepayAmounts(store, liquidity);// calculate amounts to send

        lpTokensPaid = repayAmounts(store, store.cfmm, amounts); // In Uniswap, this sends amounts and checks availability to send, in balancer this doesn't do anything

        // then update collateral
        updateCollateral(store, _loan);

        payLoan(store, _loan, lpTokensPaid);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    // TODO: Should pass expected minAmts for the swap, prevent front running
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint256[] memory) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);

        (uint256[] memory outAmts, uint256[] memory inAmts) = calcDeltaAmounts(store, deltas);

        swapAmounts(store, outAmts, inAmts);

        updateCollateral(store, _loan);

        checkMargin(_loan, 850);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        return _loan.tokensHeld;
    }

    function calcLiquidityChange(uint256 lpTokens, uint256 numerator, uint256 denominator) internal virtual pure returns(uint256) {
        return lpTokens * numerator / denominator;
    }

    function openLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 lpTokens) internal virtual {
        uint256 liquidity = calcLiquidityChange(lpTokens, store.LP_INVARIANT, store.LP_TOKEN_BALANCE); // The liquidity it represented at that time
        store.BORROWED_INVARIANT = store.BORROWED_INVARIANT + liquidity;
        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED + lpTokens;
        store.LP_TOKEN_BALANCE = store.LP_TOKEN_BALANCE - lpTokens;
        store.LP_INVARIANT = store.LP_INVARIANT - liquidity;

        store.LP_TOKEN_BORROWED_PLUS_INTEREST = store.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokens;

        _loan.liquidity = _loan.liquidity + liquidity;
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    function payLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 lpTokens) internal virtual {
        uint256 liquidity = calcLiquidityChange(lpTokens, store.BORROWED_INVARIANT, store.LP_TOKEN_BORROWED_PLUS_INTEREST);// lpTokens * store.BORROWED_INVARIANT / store.LP_TOKEN_BORROWED_PLUS_INTEREST;
        store.LP_TOKEN_BALANCE = store.LP_TOKEN_BALANCE + lpTokens;
        store.LP_INVARIANT = store.LP_INVARIANT + liquidity;

        uint256 lpTokenPrincipal;
        if(liquidity >= _loan.liquidity) {
            lpTokenPrincipal = _loan.lpTokens;
            liquidity = _loan.liquidity;
            lpTokens = (liquidity * store.LP_TOKEN_BORROWED_PLUS_INTEREST) / store.BORROWED_INVARIANT; // need to round down
        } else {
            lpTokenPrincipal = (liquidity * _loan.lpTokens) / _loan.liquidity;
        }

        _loan.liquidity = _loan.liquidity - liquidity;
        _loan.lpTokens = _loan.lpTokens - lpTokenPrincipal;
        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED - lpTokenPrincipal;

        store.BORROWED_INVARIANT = store.BORROWED_INVARIANT - liquidity; // won't overflow
        store.TOTAL_INVARIANT = store.LP_INVARIANT + store.BORROWED_INVARIANT;

        store.LP_TOKEN_BORROWED_PLUS_INTEREST = store.LP_TOKEN_BORROWED_PLUS_INTEREST - lpTokens; // won't overflow
        store.LP_TOKEN_TOTAL = store.LP_TOKEN_BALANCE + store.LP_TOKEN_BORROWED_PLUS_INTEREST;
    }
}
