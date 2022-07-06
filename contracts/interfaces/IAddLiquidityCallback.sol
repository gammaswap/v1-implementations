// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/PoolAddress.sol";

/// @title Callback for IAddLiquidityCallback#addLiquidityCallback
/// @notice Any contract that calls IUniswapV3PoolActions#mint must implement this interface
interface IAddLiquidityCallback {

    struct AddLiquidityCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    /// @notice Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param destination destination of where we are sending the token amounts to (CFMM pool)
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function addLiquidityCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        address destination,
        bytes calldata data
    ) external;
}