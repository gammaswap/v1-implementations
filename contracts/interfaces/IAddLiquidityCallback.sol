// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/PoolAddress.sol";

/// @title Callback for IAddLiquidityCallback#addLiquidityCallback
/// @notice Any contract that calls IUniswapV3PoolActions#mint must implement this interface
interface IAddLiquidityCallback {

    struct AddLiquidityCallbackData {
        address payer;
        address payee;
        uint24 protocol;
    }

    function addLiquidityCallback(
        uint24 protocol,
        address[] calldata tokens,
        uint256[] calldata amounts,
        address payer,
        address payee
    ) external;
}