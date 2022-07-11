// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Callback for IAddLiquidityCallback#addLiquidityCallback
/// @notice Any contract that calls IUniswapV3PoolActions#mint must implement this interface
interface IAddLiquidityCallback {

    struct AddLiquidityCallbackData {
        bytes32 poolKey;
        address payer;
    }

    function addLiquidityCallback(
        address payee,
        address[] calldata tokens,
        uint[] calldata amounts,
        bytes calldata data
    ) external;
}