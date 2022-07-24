// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseStrategy.sol";
import "../../interfaces/strategies/IShortStrategy.sol";
import "../../interfaces/ISendTokensCallback.sol";

abstract contract ShortStrategy is IShortStrategy, BaseStrategy {

    //ShortGamma
    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal virtual returns (uint256[] memory amounts, address payee);

    //********* Short Gamma Functions *********//
    function mint(address to) public virtual override returns(uint256 liquidity) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
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

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) public virtual override returns(uint256[] memory amounts) {
        //get the liquidity tokens
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 amount = store.balanceOf[address(this)];
        require(amount > 0, '0 dep');

        updateIndex(store);

        uint256 withdrawLPTokens = (amount * store.LP_TOKEN_TOTAL) / store.totalSupply;
        require(withdrawLPTokens < store.LP_TOKEN_BALANCE, '> liq');

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call strategy and ask strategy to use callback to transfer to CFMM then strategy calls burn
        //Bal/Crv: U -> GP -> Strategy -> CFMM -> Strategy -> U
        //                    just call strategy and ask strategy to use callback to transfer to Strategy then to CFMM
        //                    Since CFMM has to pull from strategy, strategy must always check it has enough approval
        amounts = withdrawFromCFMM(store.cfmm, to, withdrawLPTokens);
        _burn(address(this), amount);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));
        //emit Burn(msg.sender, _amount0, _amount1, uniLiquidity, to);
    }

    function addLiquidity(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override returns(uint256[] memory amounts, uint256 liquidity) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        address payee;
        (amounts, payee) = calcDepositAmounts(store, amountsDesired, amountsMin);

        address[] storage tokens = store.tokens;
        uint256[] memory balances = new uint256[](tokens.length);
        for(uint256 i = 0; i < tokens.length; i++) {
            balances[i] = GammaSwapLibrary.balanceOf(tokens[i], address(this));
        }
        ISendTokensCallback(msg.sender).sendTokensCallback(tokens, amounts, payee, data);
        for(uint256 i = 0; i < tokens.length; i++) {
            if(amounts[i] > 0) require(balances[i] + amounts[i] == GammaSwapLibrary.balanceOf(tokens[i], address(this)), "WL");
        }

        depositToCFMM(store.cfmm, amounts, address(this));

        liquidity = mint(to);
    }
}
