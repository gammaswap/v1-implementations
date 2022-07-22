// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/GammaPoolStorage.sol";
import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/ISendTokensCallback.sol";

abstract contract BaseModule {

    function calcInvariant(address cfmm, uint[] memory amounts) internal virtual view returns(uint256);

    function calcCFMMTotalInvariant(address cfmm) internal virtual view returns(uint256);

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual view returns(uint256);

    //function repayLiquidity(address cfmm, uint256 liquidity, address[] storage tokens, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld, uint256[] memory amounts, uint256 _lpTokensPaid, uint256 _liquidityPaid);
    function repayLiquidity(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld, uint256[] memory amounts, uint256 _lpTokensPaid, uint256 _liquidityPaid);

    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);
    //function rebalancePosition(address cfmm, uint256 liquidity, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);

    //function rebalancePosition(address cfmm, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);
    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual returns(uint256[] memory _tokensHeld);

    function calcAmounts(address cfmm, uint[] calldata amountsDesired, uint[] calldata amountsMin) internal virtual returns (uint[] memory amounts, address payee);

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual;

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual returns(uint[] memory amounts);

    function updateIndex(GammaPoolStorage.GammaPoolStore storage store) internal virtual {
        store.borrowRate = calcBorrowRate(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED);
        {
            uint256 lastCFMMInvariant = calcCFMMTotalInvariant(store.cfmm);
            uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(store.cfmm);
            if(lastCFMMTotalSupply > 0) {
                uint256 denominator = (store.lastCFMMInvariant * lastCFMMTotalSupply) / (10**18);
                store.lastCFMMFeeIndex = (lastCFMMInvariant * store.lastCFMMTotalSupply) / denominator;
            } else {
                store.lastCFMMFeeIndex = 10**18;
            }
            store.lastCFMMInvariant = lastCFMMInvariant;
            store.lastCFMMTotalSupply = lastCFMMTotalSupply;
        }

        if(store.lastCFMMFeeIndex > 0) {
            uint256 blockDiff = block.number - store.LAST_BLOCK_NUMBER;
            uint256 adjBorrowRate = (blockDiff * store.borrowRate) / 2252571;//2252571 year block count
            store.lastFeeIndex = store.lastCFMMFeeIndex + adjBorrowRate;
        } else {
            store.lastFeeIndex = 10**18;
        }

        store.BORROWED_INVARIANT = (store.BORROWED_INVARIANT * store.lastFeeIndex) / (10**18);

        store.LP_BORROWED = (store.BORROWED_INVARIANT * store.lastCFMMTotalSupply ) / store.lastCFMMInvariant;
        store.LP_INVARIANT = (store.LP_TOKEN_BALANCE * store.lastCFMMInvariant) / store.lastCFMMTotalSupply;
        store.LP_TOKEN_TOTAL = store.LP_TOKEN_BALANCE + store.LP_BORROWED;
        store.TOTAL_INVARIANT = store.LP_INVARIANT + store.BORROWED_INVARIANT;

        store.accFeeIndex = (store.accFeeIndex * store.lastFeeIndex) / (10**18);
        store.LAST_BLOCK_NUMBER = block.number;

        if(store.BORROWED_INVARIANT > 0) {
            (address feeTo, uint devFee) = IGammaPoolFactory(store.factory).feeInfo();
            if(feeTo != address(0) && devFee > 0) {
                 //Formula:
                 //        accumulatedGrowth: (1 - [borrowedInvariant/(borrowedInvariant*index)])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
                 //        accumulatedGrowth: (1 - [1/index])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
                 //        sharesToIssue: totalGammaTokenSupply*accGrowth/(1-accGrowth)
                uint256 totalInvariantInCFMM = ((store.LP_TOKEN_BALANCE * store.lastCFMMInvariant) / store.lastCFMMTotalSupply);//How much Invariant does this contract have from LP_TOKEN_BALANCE
                uint256 factor = ((store.lastFeeIndex - (10**18)) * devFee) / store.lastFeeIndex;//Percentage of the current growth that we will give to devs
                uint256 accGrowth = (factor * store.BORROWED_INVARIANT) / (store.BORROWED_INVARIANT + totalInvariantInCFMM);
                _mint(feeTo, (store.totalSupply * accGrowth) / ((10**18) - accGrowth));
            }
        }
    }

    function updateLoan(GammaPoolStorage.GammaPoolStore storage store, GammaPoolStorage.Loan storage _loan) internal {
        updateIndex(store);
        _loan.liquidity = (_loan.liquidity * store.accFeeIndex) / _loan.rateIndex;
        _loan.rateIndex = store.accFeeIndex;
    }/**/

    //TODO: Can be delegated (Part of Abstract Contract)
    //********* Short Gamma Functions *********//
    function mint(address to) public virtual returns(uint256 liquidity) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        uint256 depLPBal = GammaSwapLibrary.balanceOf(store.cfmm, address(this)) - store.LP_TOKEN_BALANCE;
        require(depLPBal > 0, '0 dep');

        updateIndex(store);

        uint256 depositedInvariant = (depLPBal * store.lastCFMMInvariant) / store.lastCFMMTotalSupply;

        uint256 _totalSupply = store.totalSupply;
        if (_totalSupply == 0) {
            liquidity = depositedInvariant - store.MINIMUM_LIQUIDITY;
            _mint(address(0), store.MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = (depositedInvariant * _totalSupply) / store.TOTAL_INVARIANT;
        }
        _mint(to, liquidity);
        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));
        //emit Mint(msg.sender, amountA, amountB);
    }

    //TODO: Can be delegated (Part of Abstract Contract)
    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) public virtual returns (uint[] memory amounts) {
        //get the liquidity tokens
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        uint256 amount = store.balanceOf[address(this)];
        require(amount > 0, '0 dep');

        updateIndex(store);

        uint256 withdrawLPTokens = (amount * store.LP_TOKEN_TOTAL) / store.totalSupply;
        require(withdrawLPTokens < store.LP_TOKEN_BALANCE, '> liq');

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call module and ask module to use callback to transfer to CFMM then module calls burn
        //Bal/Crv: U -> GP -> Module -> CFMM -> Module -> U
        //                    just call module and ask module to use callback to transfer to Module then to CFMM
        //                    Since CFMM has to pull from module, module must always check it has enough approval
        //amounts = IProtocolModule(_module).burn(cfmm, to, withdrawLPTokens);
        amounts = withdrawFromCFMM(store.cfmm, to, withdrawLPTokens);
        _burn(address(this), amount);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));
        //emit Burn(msg.sender, _amount0, _amount1, uniLiquidity, to);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(amount > 0, '0 amt');
        //totalSupply += amount;
        //_balanceOf[account] += amount;
        //emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "0 address");
        //uint256 accountBalance = _balanceOf[account];
        //require(accountBalance >= amount, "> balance");
        //unchecked {
        //    _balanceOf[account] = accountBalance - amount;
        //}
        //totalSupply -= amount;
        //emit Transfer(account, address(0), amount);
    }/**/

    function addLiquidity(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual returns(uint256[] memory amounts) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        address payee;
        (amounts, payee) = calcAmounts(store.cfmm, amountsDesired, amountsMin);

        uint256[] memory balances = new uint256[](store.tokens.length);
        for(uint i = 0; i < store.tokens.length; i++) {
            balances[i] = GammaSwapLibrary.balanceOf(store.tokens[i], address(this));
        }
        ISendTokensCallback(msg.sender).sendTokensCallback(store.tokens, amounts, payee, data);
        for(uint i = 0; i < store.tokens.length; i++) {
            if(amounts[i] > 0) require(balances[i] + amounts[i] == GammaSwapLibrary.balanceOf(store.tokens[i], address(this)), "WL");
        }

        depositToCFMM(store.cfmm, amounts, address(this));

        mint(to);
    }

    ////*********Long Gamma**********/////////

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
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual returns(uint[] memory tokensHeld){
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
    }/**/


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

        (_loan.tokensHeld, amounts, lpTokensPaid, liquidityPaid) = repayLiquidity(store, liquidity, _loan.tokensHeld);//calculate amounts and pay all in one call

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
