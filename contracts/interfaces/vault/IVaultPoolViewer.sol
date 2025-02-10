// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "@gammaswap/v1-core/contracts/interfaces/IGammaPool.sol";

interface IVaultPoolViewer {

    struct VaultPoolData {
        IGammaPool.PoolData poolData;
        uint256 reservedBorrowedInvariant;
        uint256 reservedLPTokens;
    }

    /// @dev Returns vault pool storage data updated to their latest values
    /// @notice Difference with getVaultPoolData() is this struct is what PoolData would return if an update of the GammaPool were to occur at the current block
    /// @param pool - address of pool to get pool data for
    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getLatestVaultPoolData(address pool) external view returns(VaultPoolData memory data);

    /// @dev Return vault pool storage data
    /// @param pool - address of pool to get pool data for
    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getVaultPoolData(address pool) external view returns(VaultPoolData memory data);
}
