// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0x14f6023825b5ea489c24560eac94b9c8eee6bfbd0cd872cd8be29d4d6e3200ef;

    function getPoolKey(address cfmm, uint24 protocol) internal pure returns(bytes32 key) {
        key = keccak256(abi.encode(cfmm, protocol));
    }

    function calcAddress(address factory, bytes32 key) internal pure returns (address pool) {
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

    function calcAddress(address factory, bytes32 key, bytes32 initCodeHash) internal pure returns (address) {
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