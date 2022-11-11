// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./ShortStrategy.sol";

abstract contract ShortStrategyERC4626 is ShortStrategy {

    function _deposit(uint256 assets, address to) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);

        // Check for rounding error since we round down in previewDeposit.
        shares = _convertToShares(store, assets);
        if(shares == 0) {
            revert ZeroShares();
        }
        _depositAssetsFrom(store, msg.sender, to, assets, shares);
    }

    function _mint(uint256 shares, address to) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);

        // No need to check for rounding error, previewMint rounds up.
        assets = _convertToAssets(store, shares);
        if(assets == 0) {
            revert ZeroAssets();
        }
        _depositAssetsFrom(store, msg.sender, to, assets, shares);
    }

    function _withdraw(uint256 assets, address to, address from) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);

        if(assets > store.LP_TOKEN_BALANCE) {//TODO: assets <= store.LP_TOKEN_BALANCE must be true. This is what maxWithdraw is
            revert ExcessiveWithdrawal();
        }

        shares = _convertToShares(store, assets);
        if(shares == 0) {
            revert ZeroShares();
        }
        _withdrawAssets(store, msg.sender, to, from, assets, shares, false);
    }

    function _redeem(uint256 shares, address to, address from) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        updateIndex(store);
        assets = _convertToAssets(store, shares);
        if(assets == 0) {
            revert ZeroAssets();
        }
        if(assets > store.LP_TOKEN_BALANCE) {//TODO: assets <= store.LP_TOKEN_BALANCE must be true. This is what maxRedeem is
            revert ExcessiveWithdrawal();
        }
        _withdrawAssets(store, msg.sender, to, from, assets, shares, false);
    }

    function _depositAssetsFrom(
        GammaPoolStorage.Store storage store,
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        GammaSwapLibrary.safeTransferFrom(IERC20(store.cfmm), caller, address(this), assets);
        _depositAssets(store, caller, receiver, assets, shares);
    }
}