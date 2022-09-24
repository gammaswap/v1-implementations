// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@gammaswap/v1-core/contracts/interfaces/strategies/base/IShortStrategy.sol";
import "./BaseStrategy.sol";
import "../../interfaces/ISendTokensCallback.sol";

abstract contract ShortStrategy is IShortStrategy, BaseStrategy {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    //ShortGamma
    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal virtual returns (uint256[] memory reserves, address payee);

    function getReserves(address cfmm) internal virtual view returns(uint256[] memory);

    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum) public view virtual override returns(uint256) {
        uint256 lastCFMMInvariant = calcInvariant(cfmm, getReserves(cfmm));
        uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
        uint256 lastFeeIndex = calcFeeIndex(calcCFMMFeeIndex(lastCFMMInvariant, lastCFMMTotalSupply, prevCFMMInvariant, prevCFMMTotalSupply), calcBorrowRate(lpBalance, lpBorrowed), lastBlockNum);
        return lpBalance + calcLPTokenBorrowedPlusInterest(accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex), lastCFMMTotalSupply, lastCFMMInvariant);
    }

    //********* Short Gamma Functions *********//
    function _depositNoPull(address to) public virtual override lock returns(uint256 shares) {//TODO: Should probably change the name of this function (addReserves)
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 assets = GammaSwapLibrary.balanceOf(store.cfmm, address(this)) - store.LP_TOKEN_BALANCE;
        require(assets > 0, "0 dep");

        updateIndex(store);

        require((shares = _previewDeposit(store, assets)) != 0, "ZERO_SHARES");

        _mint(store, to, shares);
        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    function _withdrawNoPull(address to) public virtual override lock returns(uint256 assets) {//TODO: Should probably change the name of this function (addReserves)
        //get the liquidity tokens
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 shares = store.balanceOf[address(this)];
        require(shares > 0, "0 shares");

        updateIndex(store);

        require((assets = _previewRedeem(store, shares)) <= store.LP_TOKEN_BALANCE, "> liq");

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call strategy and ask strategy to use callback to transfer to CFMM then strategy calls burn
        //Bal/Crv: U -> GP -> Strategy -> CFMM -> Strategy -> U
        //                    just call strategy and ask strategy to use callback to transfer to Strategy then to CFMM
        //                    Since CFMM has to pull from strategy, strategy must always check it has enough approval
        address cfmm = store.cfmm;
        GammaSwapLibrary.safeTransfer(cfmm, to, assets);
        _burn(store, address(this), shares);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override lock returns(uint256[] memory reserves, uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        address payee;
        (reserves, payee) = calcDepositAmounts(store, amountsDesired, amountsMin);

        address[] storage tokens = store.tokens;
        uint256[] memory balances = new uint256[](tokens.length);
        for(uint256 i = 0; i < tokens.length; i++) {
            balances[i] = GammaSwapLibrary.balanceOf(tokens[i], address(this));
        }
        ISendTokensCallback(msg.sender).sendTokensCallback(tokens, reserves, payee, data); // TODO: Risky? What could go wrong before depositing?
        for(uint256 i = 0; i < tokens.length; i++) {
            if(reserves[i] > 0) require(balances[i] + reserves[i] == GammaSwapLibrary.balanceOf(tokens[i], address(this)), "WL");
        }

        depositToCFMM(store.cfmm, reserves, address(this));

        shares = _depositNoPull(to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function _withdrawReserves(address to) public virtual override lock returns(uint256[] memory reserves, uint256 assets) {//TODO: Should probably change the name of this function (maybe withdrawReserves)
        //get the liquidity tokens
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 shares = store.balanceOf[address(this)];
        require(shares > 0, "0 shares");

        updateIndex(store);

        require((assets = _previewRedeem(store, shares)) <= store.LP_TOKEN_BALANCE, "> liq");

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call strategy and ask strategy to use callback to transfer to CFMM then strategy calls burn
        //Bal/Crv: U -> GP -> Strategy -> CFMM -> Strategy -> U
        //                    just call strategy and ask strategy to use callback to transfer to Strategy then to CFMM
        //                    Since CFMM has to pull from strategy, strategy must always check it has enough approval
        reserves = withdrawFromCFMM(store.cfmm, to, assets);
        _burn(store, address(this), shares);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    //*************ERC-4626 functions************//

    function _deposit(uint256 assets, address to) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        // Check for rounding error since we round down in previewDeposit.
        require((shares = _previewDeposit(store, assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        GammaSwapLibrary.safeTransferFrom(store.cfmm, msg.sender, address(this), assets);

        _mint(store, to, shares);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit Deposit(msg.sender, to, assets, shares);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);

        afterDeposit(store, assets, shares);
    }

    function _mint(uint256 shares, address to) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        assets = _previewMint(store, shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        GammaSwapLibrary.safeTransferFrom(store.cfmm, msg.sender, address(this), assets);

        _mint(store, to, shares);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit Deposit(msg.sender, to, assets, shares);

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);

        afterDeposit(store, assets, shares);
    }

    function _withdraw(uint256 assets, address to, address from) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        require(assets <= store.LP_TOKEN_BALANCE, "> liq");

        shares = _previewWithdraw(store, assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != from) {
            uint256 allowed = store.allowance[from][msg.sender]; // Saves gas for limited approvals.
            if (allowed != type(uint256).max) store.allowance[from][msg.sender] = allowed - shares;
        }

        beforeWithdraw(store, assets, shares);

        _burn(store, from, shares);

        emit Withdraw(msg.sender, to, from, assets, shares);

        GammaSwapLibrary.safeTransfer(store.cfmm, to, assets);
        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    function _redeem(uint256 shares, address to, address from) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        if (msg.sender != from) {
            uint256 allowed = store.allowance[from][msg.sender]; // Saves gas for limited approvals.
            if (allowed != type(uint256).max) store.allowance[from][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = _previewRedeem(store, shares)) != 0, "ZERO_ASSETS");
        require(assets <= store.LP_TOKEN_BALANCE, "> liq");

        beforeWithdraw(store, assets, shares);

        _burn(store, from, shares);

        emit Withdraw(msg.sender, to, from, assets, shares);

        GammaSwapLibrary.safeTransfer(store.cfmm, to, assets);
        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    //ACCOUNTING LOGIC

    function _convertToShares(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = store.LP_TOKEN_TOTAL;
        return supply == 0 || _totalAssets == 0 ? assets : (assets * supply) / _totalAssets;
    }

    function _convertToAssets(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply;
        return supply == 0 ? shares : (shares * store.LP_TOKEN_TOTAL) / supply;
    }

    function _previewDeposit(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        return _convertToShares(store, assets);
    }

    function _previewMint(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        return _convertToAssets(store, shares);
    }

    function _previewWithdraw(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        return _convertToShares(store, assets);
    }

    function _previewRedeem(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        return _convertToAssets(store, shares);
    }

    //INTERNAL HOOKS LOGIC

    function beforeWithdraw(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}
}
