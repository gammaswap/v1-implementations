// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@gammaswap/v1-core/contracts/interfaces/strategies/base/ILongStrategy.sol";
import "./BaseStrategy.sol";

abstract contract LongStrategy is ILongStrategy, BaseStrategy {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    //LongGamma
    function sendAmounts(GammaPoolStorage.Store storage store, address to, uint256[] memory amounts, bool force) internal virtual;

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

    function incrementCollateral(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal virtual {
        for (uint256 i = 0; i < store.tokens.length; i++) {
            uint256 tokenBal = GammaSwapLibrary.balanceOf(store.tokens[i], address(this)) - store.TOKEN_BALANCE[i];
            if(tokenBal == 0)
                continue;
            _loan.tokensHeld[i] = _loan.tokensHeld[i] + tokenBal;
            store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] + tokenBal;
        }
        _loan.heldLiquidity = calcInvariant(store.cfmm, _loan.tokensHeld);
    }

    function decrementCollateral(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory amounts, bool isCalcInvariant) internal virtual {
        for(uint256 i = 0; i < store.tokens.length; i++) {
            if(amounts[i] == 0)
                continue;
            require(_loan.tokensHeld[i] >= amounts[i], "> held");
            require(store.TOKEN_BALANCE[i] >= amounts[i], "> bal");
            unchecked {
                _loan.tokensHeld[i] = _loan.tokensHeld[i] - amounts[i];
                store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] - amounts[i];
            }
        }

        if(isCalcInvariant)
            _loan.heldLiquidity = calcInvariant(store.cfmm, _loan.tokensHeld);
    }

    function _increaseCollateral(uint256 tokenId) external virtual override lock returns(uint256[] memory) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        incrementCollateral(store, _loan);
        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
        return _loan.tokensHeld;
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override lock returns(uint256[] memory) {
        require(to != address(this));
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        decrementCollateral(store, _loan, amounts, true);

        sendAmounts(store, to, amounts, true);// TODO: Should probably call a different function here that always sends. Maybe this function should be in Base, not even CPMMBase. The only downside is gas usage because of for loop

        updateLoan(store, _loan);

        checkMargin(_loan, 800);
        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
        return _loan.tokensHeld;
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        require(lpTokens < store.LP_TOKEN_BALANCE, "> liq");

        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        updateLoan(store,_loan);

        amounts = withdrawFromCFMM(store.cfmm, address(this), lpTokens);

        incrementCollateral(store, _loan);

        openLoan(store, _loan, lpTokens);
        require(store.LP_TOKEN_BALANCE == GammaSwapLibrary.balanceOf(store.cfmm, address(this)), "LP < Bal");

        checkMargin(_loan, 800);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override lock returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store, _loan);

        amounts = calcRepayAmounts(store, liquidity);//calculate amounts to send

        decrementCollateral(store, _loan, amounts, true);

        sendAmounts(store, store.cfmm, amounts, false); // In Uniswap, this sends amounts, in balancer this doesn't do anything

        lpTokensPaid = depositToCFMM(store.cfmm, amounts, address(this));//send (in balancer we send tokens here)

        payLoan(store, _loan, lpTokensPaid);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint256[] memory) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);

        (uint256[] memory outAmts, uint256[] memory inAmts) = calcDeltaAmounts(store, deltas);

        decrementCollateral(store, _loan, outAmts, false);

        swapAmounts(store, outAmts, inAmts);

        incrementCollateral(store, _loan);

        checkMargin(_loan, 850);

        emit LoanUpdated(tokenId, _loan.tokensHeld, _loan.heldLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);

        return _loan.tokensHeld;
    }

    function openLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 lpTokens) internal virtual {
        uint256 liquidity = (lpTokens * store.LP_INVARIANT) / store.LP_TOKEN_BALANCE;
        store.BORROWED_INVARIANT = store.BORROWED_INVARIANT + liquidity;
        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED + lpTokens;
        store.LP_TOKEN_BALANCE = store.LP_TOKEN_BALANCE - lpTokens;

        store.LP_TOKEN_BORROWED_PLUS_INTEREST = store.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokens;
        store.LP_INVARIANT = store.LP_INVARIANT - liquidity;

        _loan.liquidity = _loan.liquidity + liquidity;
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    function payLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 lpTokens) internal virtual {
        uint256 liquidity = lpTokens * store.BORROWED_INVARIANT / store.LP_TOKEN_BORROWED_PLUS_INTEREST;
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
