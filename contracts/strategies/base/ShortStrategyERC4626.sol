// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./ShortStrategy.sol";

abstract contract ShortStrategyERC4626 is ShortStrategy {
    function _deposit(uint256 assets, address to) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);

        // Check for rounding error since we round down in previewDeposit.
        require((shares = _convertToShares(store, assets)) != 0, "ZERO_SHARES");
        _depositAssetsFrom(store, msg.sender, to, assets, shares);
    }

    function _mint(uint256 shares, address to) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);

        // No need to check for rounding error, previewMint rounds up.
        require((assets = _convertToAssets(store, shares)) != 0, "ZERO_ASSETS");
        _depositAssetsFrom(store, msg.sender, to, assets, shares);
    }

    function _withdraw(uint256 assets, address to, address from) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);
        require(assets <= store.LP_TOKEN_BALANCE, "withdraw > max"); //TODO: This is what maxWithdraw is
        require((shares = _convertToShares(store, assets)) != 0, "ZERO_SHARES");
        _withdrawAssets(store, msg.sender, to, from, assets, shares, false);
    }

    function _redeem(uint256 shares, address to, address from) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);
        require((assets = _convertToAssets(store, shares)) != 0, "ZERO_ASSETS");
        require(assets <= store.LP_TOKEN_BALANCE, "redeem > max"); //TODO: This is what maxRedeem is
        _withdrawAssets(store, msg.sender, to, from, assets, shares, false);
    }

    function _depositAssetsFrom(
        GammaPoolStorage.Store storage store,
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        GammaSwapLibrary.safeTransferFrom(store.cfmm, caller, address(this), assets);
        _depositAssets(store, caller, receiver, assets, shares);
    }
}