// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0x44d02e958d6e2c08ac7280e9ca2a8e8cb343d473a754e6d4f83e830cb508c9cb;

    /// @notice Returns key: the ordered tokens with the matched fee levels
    /// @param cfmm The pool address
    /// @param protocol The protocol id of the pool
    /// @return key unique identifier of the GammaPool
    function getPoolKey(address cfmm, uint24 protocol) internal pure returns(bytes32 key) {
        key = keccak256(abi.encode(cfmm, protocol));
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, bytes32 key) internal pure returns (address pool) {
        //require(key.token0 < key.token1);
        pool = address(
                uint160(
                    uint256(keccak256(
                        abi.encodePacked(
                            hex'ff',
                            factory,
                            key,
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }


    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, bytes32 key, bytes32 initCodeHash) internal pure returns (address) {
        //require(key.token0 < key.token1);
        return address(
            uint160(
                uint256(keccak256(
                    abi.encodePacked(
                        hex'ff',
                        factory,
                        key,
                        initCodeHash
                    )
                )
                )
            )
        );
    }
}