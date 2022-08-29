// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../strategies/base/ShortStrategy.sol";
import "../libraries/storage/GammaPoolStorage.sol";

contract TestShortStrategy is ShortStrategy {

    constructor() {
        GammaPoolStorage.init();
    }

    GammaPoolStorage.Store store;

    function _previewDepositTest(uint256 assets) external {
        _previewDeposit(store, assets);
    }

    function _previewMintTest(uint256 shares) external {
        _previewMint(store, shares);
    }

    function _previewWithdrawTest(uint256 assets) external {
        _previewWithdraw(store, assets);
    }

    function _previewRedeemTest(uint256 shares) external {
        _previewRedeem(store, shares);
    }

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed)
        internal
        view
        virtual
        override
        returns (uint256)
    {}

    function updateReserves(GammaPoolStorage.Store storage store)
        internal
        virtual
        override
    {}

    function calcInvariant(address cfmm, uint256[] memory amounts)
        internal
        view
        virtual
        override
        returns (uint256)
    {}

    function depositToCFMM(
        address cfmm,
        uint256[] memory amounts,
        address to
    ) internal virtual override returns (uint256 liquidity) {}

    function withdrawFromCFMM(
        address cfmm,
        address to,
        uint256 amount
    ) internal virtual override returns (uint256[] memory amounts) {}

    function calcDepositAmounts(
        GammaPoolStorage.Store storage store,
        uint256[] calldata amountsDesired,
        uint256[] calldata amountsMin
    )
        internal
        virtual
        override
        returns (uint256[] memory reserves, address payee)
    {}

    function getReserves(address cfmm)
        internal
        view
        virtual
        override
        returns (uint256[] memory)
    {}
}