// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface Vault Short Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Used to calculate total supply and assets from Short Strategy accounting for reserved borrowed liquidity
interface IVaultShortStrategy {
    /// @dev Parameters used to calculate the GS LP tokens and CFMM LP tokens in the GammaPool after protocol fees and accrued interest
    struct VaultReservedBalancesParams {
        /// @dev address of factory contract of GammaPool
        address factory;
        /// @dev address of GammaPool
        address pool;
        /// @dev address of contract holding rate parameters for pool
        address paramsStore;
        /// @dev storage number of borrowed liquidity invariant in GammaPool
        uint256 BORROWED_INVARIANT;
        /// @dev storage number of reserved borrowed liquidity invariant in GammaPool
        uint256 RESERVED_BORROWED_INVARIANT;
        /// @dev current liquidity invariant in CFMM
        uint256 latestCfmmInvariant;
        /// @dev current total supply of CFMM LP tokens in existence
        uint256 latestCfmmTotalSupply;
        /// @dev last block number GammaPool was updated
        uint256 LAST_BLOCK_NUMBER;
        /// @dev CFMM liquidity invariant at time of last update of GammaPool
        uint256 lastCFMMInvariant;
        /// @dev CFMM LP Token supply at time of last update of GammaPool
        uint256 lastCFMMTotalSupply;
        /// @dev CFMM Fee Index at time of last update of GammaPool
        uint256 lastCFMMFeeIndex;
        /// @dev current total supply of GS LP tokens
        uint256 totalSupply;
        /// @dev current LP Tokens in GammaPool counted at time of last update
        uint256 LP_TOKEN_BALANCE;
        /// @dev liquidity invariant of LP tokens in GammaPool at time of last update
        uint256 LP_INVARIANT;
    }

    /// @dev Calculate current total GS LP tokens after protocol fees and total CFMM LP tokens (real and virtual) in
    /// @dev existence in the GammaPool after accrued interest. The total assets and supply numbers returned by this
    /// @dev function are used in the ERC4626 implementation of the GammaPool
    /// @param vaultReservedBalanceParams - parameters from GammaPool to calculate current total GS LP Tokens and CFMM LP Tokens after fees and interest
    /// @return assets - total CFMM LP tokens in existence in the pool (real and virtual) including accrued interest
    /// @return supply - total GS LP tokens in the pool including accrued interest
    function totalReservedAssetsAndSupply(VaultReservedBalancesParams memory vaultReservedBalanceParams) external view returns(uint256 assets, uint256 supply);
}
