// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

interface IBalancerStrategy {
    enum StorageIndexes { POOL_ID, VAULT, SCALING_FACTOR0, SCALING_FACTOR1 }

    function weight0() external view returns (uint256);

}
