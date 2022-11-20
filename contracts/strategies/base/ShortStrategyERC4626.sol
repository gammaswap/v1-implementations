// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./ShortStrategy.sol";

abstract contract ShortStrategyERC4626 is ShortStrategy {

    function _deposit(uint256 assets, address to) external virtual override lock returns(uint256 shares) {
        updateIndex();

        // Check for rounding error since we round down in previewDeposit.
        shares = _convertToShares(assets);
        if(shares == 0) {
            revert ZeroShares();
        }
        _depositAssetsFrom(msg.sender, to, assets, shares);
    }

    function _mint(uint256 shares, address to) external virtual override lock returns(uint256 assets) {
        updateIndex();

        // No need to check for rounding error, previewMint rounds up.
        assets = _convertToAssets(shares);
        if(assets == 0) {
            revert ZeroAssets();
        }
        _depositAssetsFrom(msg.sender, to, assets, shares);
    }

    function _withdraw(uint256 assets, address to, address from) external virtual override lock returns(uint256 shares) {
        updateIndex();

        if(assets > s.LP_TOKEN_BALANCE) {
            revert ExcessiveWithdrawal();
        }

        shares = _convertToShares(assets);
        if(shares == 0) {
            revert ZeroShares();
        }
        _withdrawAssets(msg.sender, to, from, assets, shares, false);
    }

    function _redeem(uint256 shares, address to, address from) external virtual override lock returns(uint256 assets) {
        updateIndex();
        assets = _convertToAssets(shares);
        if(assets == 0) {
            revert ZeroAssets();
        }
        if(assets > s.LP_TOKEN_BALANCE) {
            revert ExcessiveWithdrawal();
        }
        _withdrawAssets(msg.sender, to, from, assets, shares, false);
    }

    function _depositAssetsFrom(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        GammaSwapLibrary.safeTransferFrom(IERC20(s.cfmm), caller, address(this), assets);
        _depositAssets(caller, receiver, assets, shares);
    }
}