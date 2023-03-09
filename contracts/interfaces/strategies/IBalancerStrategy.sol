// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for BalancerStrategy contracts
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Interface to get weight, storage indices, and data struct
interface IBalancerStrategy {

    /// @dev enum indices for storage fields saved for balancer AMMs
    enum StorageIndexes { POOL_ID, VAULT, SCALING_FACTOR0, SCALING_FACTOR1 }

    /// @dev struct used to verify and initialize BalancerGammaPool as well as request latest AMM reserves
    struct BalancerPoolData {
        /// @dev pool id of AMM in vault address of Balancer
        bytes32 cfmmPoolId;
        /// @dev vault address of Balancer AMM (where reserves are actually stored)
        address cfmmVault;
        /// @dev weight of token0 in Balancer AMM
        uint256 cfmmWeight0;
    }

    /// @dev struct used to verify and initialize BalancerGammaPool as well as request latest AMM reserves
    struct BalancerInvariantRequest {
        /// @dev pool id of AMM in vault address of Balancer
        bytes32 cfmmPoolId;
        /// @dev vault address of Balancer AMM (where reserves are actually stored)
        address cfmmVault;
        /// @dev factors to scale reserves for invariant calculation
        uint256[] scalingFactors;
    }

    /// @dev struct used to verify and initialize BalancerGammaPool as well as request latest AMM reserves
    struct BalancerReservesRequest {
        /// @dev pool id of AMM in vault address of Balancer
        bytes32 cfmmPoolId;
        /// @dev vault address of Balancer AMM (where reserves are actually stored)
        address cfmmVault;
    }

    /// @return weight of token0 in Balancer AMM
    function weight0() external view returns (uint256);

}
