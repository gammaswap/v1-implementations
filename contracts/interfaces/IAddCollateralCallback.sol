// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IBorrowLiquidityCallback {
    struct BorrowLiquidityCallbackData {
        bytes32 poolKey;
        address payer;
    }

    function borrowLiquidityCallback(
        address payee,
        address[] calldata tokens,
        uint[] calldata amounts,
        bytes calldata data
    ) external;
}
