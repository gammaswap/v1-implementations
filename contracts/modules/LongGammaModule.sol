pragma solidity ^0.8.0;

import "./BaseModule.sol";

abstract contract LongGammaModule is BaseModule {

    //LongGamma
    function calcRepayAmounts(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld)
        internal virtual returns(uint256[] memory _tokensHeld, uint256[] memory amounts);

    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);

    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);

    function getLoan(GammaPoolStorage.GammaPoolStore storage store, uint256 tokenId) internal returns(GammaPoolStorage.Loan storage _loan) {
        _loan = store.loans[tokenId];
        require(_loan.id > 0, '0 id');
        require(tokenId == uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id))), 'FORBIDDEN');
    }

    function checkMargin(GammaPoolStorage.Loan storage _loan, uint24 limit) internal view {
        require(_loan.heldLiquidity * limit / 1000 >= _loan.liquidity, 'margin');
    }

    function updateCollateral(GammaPoolStorage.GammaPoolStore storage store, GammaPoolStorage.Loan storage _loan) internal {
        for (uint i = 0; i < store.tokens.length; i++) {
            uint256 tokenBal = GammaSwapLibrary.balanceOf(store.tokens[i], address(this)) - store.TOKEN_BALANCE[i];
            if(tokenBal > 0) {
                _loan.tokensHeld[i] = _loan.tokensHeld[i] + tokenBal;
                store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] + tokenBal;
            }
        }
        _loan.heldLiquidity = calcInvariant(store.cfmm, _loan.tokensHeld);/**/
    }

    //TODO: Can be delegated
    function increaseCollateral(uint256 tokenId) external virtual returns(uint[] memory) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        updateCollateral(store, _loan);
        return _loan.tokensHeld;/**/
    }

    //TODO: Can be delegated
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual returns(uint[] memory tokensHeld) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        for(uint i = 0; i < store.tokens.length; i++) {
            require(_loan.tokensHeld[i] > amounts[i], '> amt');
            GammaSwapLibrary.transfer(store.tokens[i], to, amounts[i]);//TODO switch to TransferHelper.safeTransfer
            _loan.tokensHeld[i] = _loan.tokensHeld[i] - amounts[i];
            store.TOKEN_BALANCE[i] = store.TOKEN_BALANCE[i] - amounts[i];
        }

        updateLoan(store, _loan);
        tokensHeld = _loan.tokensHeld;
        _loan.heldLiquidity = calcInvariant(store.cfmm, tokensHeld);

        checkMargin(_loan, 800);
        return _loan.tokensHeld;
    }

    //TODO: Can be delegated
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual returns(uint[] memory amounts){
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();

        require(lpTokens < store.LP_TOKEN_BALANCE, '> liq');

        updateIndex(store);

        //IProtocolModule module = IProtocolModule(_module);

        //Uni/Sus: U -> GP -> CFMM -> GP
        //                    just call module and ask module to use callback to transfer to CFMM then module calls burn
        //Bal/Crv: U -> GP -> Module -> CFMM -> Module -> GP
        //                    just call module and ask module to use callback to transfer to Module then to CFMM
        //                    Since CFMM has to pull from module, module must always check it has enough approval
        amounts = withdrawFromCFMM(store.cfmm, address(this), lpTokens);

        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);
        //Pool.Loan storage _loan = getLoan(tokenId);
        updateCollateral(store, _loan);

        openLoan(store, _loan, calcInvariant(store.cfmm, amounts), lpTokens);
        require(store.LP_TOKEN_BALANCE == GammaSwapLibrary.balanceOf(store.cfmm, address(this)), 'LP < Bal');

        checkMargin(_loan, 800);
    }

    //TODO: Can be delegated
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);

        (_loan.tokensHeld, amounts) = calcRepayAmounts(store, liquidity, _loan.tokensHeld);//calculate amounts and pay all in one call

        lpTokensPaid = depositToCFMM(store.cfmm, amounts, address(this));

        liquidityPaid = lpTokensPaid * store.lastCFMMInvariant / store.lastCFMMTotalSupply;

        payLoan(store, _loan, liquidityPaid, lpTokensPaid);

        //Do I have the amounts in the tokensHeld?
        //so to swap you send the amount you want to swap to CFMM
        //Uni/Sushi/UniV3: GP -> CFMM -> GP
        //Bal/Crv: GP -> Module -> CFMM -> Module -> GP
        //UniV3
    }

    //TODO: Can be delegated (Abstract)
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual returns(uint256[] memory tokensHeld) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store,_loan);

        tokensHeld = rebalancePosition(store, deltas, _loan.tokensHeld);
        checkMargin(_loan, 850);
        _loan.tokensHeld = tokensHeld;
    }

    //TODO: Can be delegated (Abstract)
    function rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external virtual returns(uint256[] memory tokensHeld) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(store, tokenId);

        updateLoan(store, _loan);

        tokensHeld = rebalancePosition(store, liquidity, _loan.tokensHeld);
        checkMargin(_loan, 850);
        _loan.tokensHeld = tokensHeld;
    }

    function openLoan(GammaPoolStorage.GammaPoolStore storage store, GammaPoolStorage.Loan storage _loan, uint256 liquidity, uint256 lpTokens) internal {
        store.BORROWED_INVARIANT = store.BORROWED_INVARIANT + liquidity;
        store.LP_TOKEN_BORROWED = store.LP_TOKEN_BORROWED + lpTokens;
        store.LP_TOKEN_BALANCE = store.LP_TOKEN_BALANCE - lpTokens;

        _loan.liquidity = _loan.liquidity + liquidity;
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    function payLoan(GammaPoolStorage.GammaPoolStore storage store, GammaPoolStorage.Loan storage _loan, uint256 liquidity, uint256 lpTokensPaid) internal {
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
