// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

// Interface for the Balancer Vault contract
// E.g. https://etherscan.io/address/0xBA12222222228d8Ba445958a75a0704d566BF2C8

interface IVault {
    // Fetches the pool assets held in the vault
    function getPoolTokens(bytes32 poolId) external returns (address[] memory tokens, uint[] memory balances);
}
