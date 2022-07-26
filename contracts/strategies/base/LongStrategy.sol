// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseStrategy.sol";
import "../../interfaces/strategies/base/ILongStrategy.sol";

abstract contract LongStrategy is ILongStrategy, BaseStrategy {

    //LongGamma
    function calcRepayAmounts(GammaPoolStorage.Store storage store, uint256 liquidity, uint256[] storage tokensHeld)
        internal virtual returns(uint256[] memory _tokensHeld, uint256[] memory amounts);

    function rebalancePosition(GammaPoolStorage.Store storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);

    function rebalancePosition(GammaPoolStorage.Store storage store, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);

    function getLoan(GammaPoolStorage.Store storage store, uint256 tokenId) internal virtual view returns(GammaPoolStorage.Loan storage _loan) {
        _loan = store.loans[tokenId];
        require(_loan.id > 0, '0 id');
        require(tokenId == uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id))), 'FORBIDDEN');
    }

    function checkMargin(GammaPoolStorage.Loan storage _loan, uint24 limit) internal virtual view {
        require(_loan.heldLiquidity * limit / 1000 >= _loan.liquidity, 'margin');
    }

    function updateCollateral(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal virtual {
        for (uint256 i = 0; i < store.tokens.length; i++) {
            uint256 tokenBal = GammaSwapLibrary.balanceOf(store.tokens[i], address(this)) - store.TOKEN_BALANCE[i];
            if(tokenBal > 0) {
                _loan.tokensHeld[i] = _loan.tokensHeld[i] + tokenBal;
                store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] + tokenBal;
            }
        }
        _loan.heldLiquidity = calcInvariant(store.cfmm, _loan.tokensHeld);
    }

    function increaseCollateral(uint256 tokenId) external virtual override returns(uint256[] memory) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        updateCollateral(store, _loan);
        return _loan.tokensHeld;/**/
    }

    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override returns(uint256[] memory tokensHeld) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        for(uint256 i = 0; i < store.tokens.length; i++) {
            require(_loan.tokensHeld[i] > amounts[i], '> amt');
            GammaSwapLibrary.transfer(store.tokens[i], to, amounts[i]);
            _loan.tokensHeld[i] = _loan.tokensHeld[i] - amounts[i];
            store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] - amounts[i];
        }

        updateLoan(store, _loan);
        tokensHeld = _loan.tokensHeld;
        _loan.heldLiquidity = calcInvariant(store.cfmm, tokensHeld);

        checkMargin(_loan, 800);
        return _loan.tokensHeld;
    }

    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        require(lpTokens < store.LP_TOKEN_BALANCE, '> liq');

        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);
        //Uni/Sus: U -> GP -> CFMM -> GP
        //                    just call strategy and ask strategy to use callback to transfer to CFMM then strategy calls burn
        //Bal/Crv: U -> GP -> Strategy -> CFMM -> Strategy -> GP
        //                    just call strategy and ask strategy to use callback to transfer to Strategy then to CFMM
        //                    Since CFMM has to pull from strategy, strategy must always check it has enough approval
        amounts = withdrawFromCFMM(store.cfmm, address(this), lpTokens);

        updateCollateral(store, _loan);

        openLoan(store, _loan, calcInvariant(store.cfmm, amounts), lpTokens);
        require(store.LP_TOKEN_BALANCE == GammaSwapLibrary.balanceOf(store.cfmm, address(this)), 'LP < Bal');

        checkMargin(_loan, 800);
    }

    function repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);

        (_loan.tokensHeld, amounts) = calcRepayAmounts(store, liquidity, _loan.tokensHeld);//calculate amounts to send

        lpTokensPaid = depositToCFMM(store.cfmm, amounts, address(this));//send

        liquidityPaid = lpTokensPaid * store.lastCFMMInvariant / store.lastCFMMTotalSupply;

        payLoan(store, _loan, liquidityPaid, lpTokensPaid);

        //Do I have the amounts in the tokensHeld?
        //so to swap you send the amount you want to swap to CFMM
        //Uni/Sushi/UniV3: GP -> CFMM -> GP
        //Bal/Crv: GP -> Strategy -> CFMM -> Strategy -> GP
        //UniV3
    }

    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint256[] memory tokensHeld) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);

        tokensHeld = rebalancePosition(store, deltas, _loan.tokensHeld);
        checkMargin(_loan, 850);
        _loan.tokensHeld = tokensHeld;
    }

    function rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256[] memory tokensHeld) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store, _loan);

        tokensHeld = rebalancePosition(store, liquidity, _loan.tokensHeld);
        checkMargin(_loan, 850);
        _loan.tokensHeld = tokensHeld;
    }

    function openLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 liquidity, uint256 lpTokens) internal virtual {
        store.BORROWED_INVARIANT = store.BORROWED_INVARIANT + liquidity;
        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED + lpTokens;
        store.LP_TOKEN_BALANCE = store.LP_TOKEN_BALANCE - lpTokens;

        _loan.liquidity = _loan.liquidity + liquidity;
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    function payLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256 liquidity, uint256 lpTokensPaid) internal virtual {
        uint256 lpTokens = (liquidity * _loan.lpTokens / _loan.liquidity);

        if(liquidity >= _loan.liquidity) {
            liquidity = _loan.liquidity;
            lpTokens = _loan.lpTokens;
        }

        store.BORROWED_INVARIANT = store.BORROWED_INVARIANT - liquidity;
        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED - lpTokens;
        store.LP_TOKEN_BALANCE = store.LP_TOKEN_BALANCE + lpTokensPaid;

        _loan.liquidity = _loan.liquidity - liquidity;
        _loan.lpTokens = _loan.lpTokens - lpTokens;
    }
}
