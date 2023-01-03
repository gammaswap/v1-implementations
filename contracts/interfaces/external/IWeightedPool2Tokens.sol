// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

// Interface for the Balancer WeightedPool2Tokens contract
// E.g. https://etherscan.io/address/0x5c6ee304399dbdb9c8ef030ab642b10820db8f56

interface IWeightedPool2Tokens {
    // Fetches the pool weights for both assets
    function getNormalizedWeights() external returns (uint weight0, uint weight1);
    
    // Fetches the pool current invariant
    function getInvariant() external returns (uint invariant);

    // Fetches the pool previous invariant
    function getLastInvariant() external returns (uint invariant);

    // Fetches the swap fee percentage for the pool
    function getSwapFeePercentage() external returns (int swapFeePercentage);

    // Fetches the pool ID
    function getPoolId() external returns (bytes32 poolId);
}
