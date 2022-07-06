// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title An interface for a contract that is capable of deploying Uniswap V3 Pools
/// @notice A contract that constructs a pool must implement this to pass arguments to the pool
/// @dev This is used to avoid having constructor arguments in the pool contract, which results in the init code hash
/// of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
interface IGammaPoolFactory {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 protocol;
    }

    /// @notice Get the parameters to be used in constructing the pool, set transiently during pool creation.
    /// @dev Called by the pool constructor to fetch the parameters of the pool
    /// Returns factory The factory address
    /// Returns token0 The first token of the pool by address sort order
    /// Returns token1 The second token of the pool by address sort order
    /// Returns protocol The protocol id this pool is for (e.g. Uniswap, Sushiswap, etc.)
    function parameters()
    external
    view
    returns (
        address factory,
        address token0,
        address token1,
        uint24 protocol
    );
}