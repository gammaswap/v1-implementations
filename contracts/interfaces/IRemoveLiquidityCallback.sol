// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Callback for IRemoveLiquidityCallback#addLiquidityCallback
/// @notice Any contract that calls IUniswapV3PoolActions#mint must implement this interface
interface IRemoveLiquidityCallback {
    function removeLiquidityCallback(address to, uint256 amount) external;
}