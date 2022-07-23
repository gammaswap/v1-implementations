pragma solidity ^0.8.0;

import "./BaseModule.sol";

abstract contract ShortGammaModule is BaseModule {

    //ShortGamma
    function calcDepositAmounts(GammaPoolStorage.GammaPoolStore storage store, uint[] calldata amountsDesired, uint[] calldata amountsMin) internal virtual returns (uint[] memory amounts, address payee);

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

    function addLiquidity(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual returns(uint256[] memory amounts) {
        GammaPoolStorage.GammaPoolStore storage store = GammaPoolStorage.store();
        address payee;
        (amounts, payee) = calcDepositAmounts(store, amountsDesired, amountsMin);

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
}
