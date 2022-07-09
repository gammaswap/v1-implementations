// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/PoolAddress.sol";

/// @title Callback for IRemoveLiquidityCallback#addLiquidityCallback
/// @notice Any contract that calls IUniswapV3PoolActions#mint must implement this interface
interface IRemoveLiquidityCallback {

    struct RemoveLiquidityCallbackData {
        bytes32 poolKey;
        address payer;
    }

    function removeLiquidityCallback(
        address payee,
        address[] calldata tokens,
        uint[] calldata amounts,
        bytes calldata data
    ) external;
}