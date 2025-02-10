// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/base/BaseStrategy.sol";
import "../../../interfaces/vault/IVaultGammaPool.sol";

/// @title Vault Base Strategy abstract contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for Constant Product Market Maker
/// @dev This implementation was specifically designed to work with UniswapV2. Inherits Rate Model
abstract contract VaultBaseStrategy is BaseStrategy {

    using LibStorage for LibStorage.Storage;

    /// @dev Accrue interest to borrowed invariant amount excluding reserved borrowed invariant
    /// @param borrowedInvariant - liquidity invariant borrowed in the GammaPool
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @return newBorrowedInvariant - borrowed invariant with accrued interest
    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual override view returns(uint256) {
        uint256 reservedBorrowedInvariant = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_BORROWED_INVARIANT));
        reservedBorrowedInvariant = GSMath.min(borrowedInvariant,reservedBorrowedInvariant);
        unchecked {
            borrowedInvariant = borrowedInvariant - reservedBorrowedInvariant;
        }
        return  _accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex) + reservedBorrowedInvariant;
    }

    /// @dev Accrue interest to borrowed invariant amount
    /// @param borrowedInvariant - liquidity invariant borrowed in the GammaPool
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @return newBorrowedInvariant - borrowed invariant with accrued interest
    function _accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual view returns(uint256) {
        return  super.accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
    }

    /// @dev Revert if lpTokens withdrawal causes utilization rate to go over 98%
    /// @param lpTokens - lpTokens expected to change utilization rate
    /// @param isLoan - true if lpTokens are being borrowed
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override view {
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 reservedLPTokens = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));

        uint256 reservedLPInvariant = convertLPToInvariant(reservedLPTokens, lastCFMMInvariant, lastCFMMTotalSupply);
        uint256 lpTokenInvariant = convertLPToInvariant(lpTokens, lastCFMMInvariant, lastCFMMTotalSupply);
        uint256 lpInvariant = s.LP_INVARIANT;
        lpInvariant = lpInvariant >= reservedLPInvariant ? lpInvariant - reservedLPInvariant : 0;

        if(lpInvariant < lpTokenInvariant) revert NotEnoughLPInvariant();
        unchecked {
            lpInvariant = lpInvariant - lpTokenInvariant;
        }
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + (isLoan ? lpTokenInvariant : 0) + reservedLPInvariant;
        if(calcUtilizationRate(lpInvariant, borrowedInvariant) > 98e16) {
            revert MaxUtilizationRate();
        }
    }

    function getAdjLPTokenBalance() internal virtual view returns(uint256 lpTokenBalance) {
        uint256 reservedLPTokens = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        reservedLPTokens = GSMath.min(lpTokenBalance, reservedLPTokens);
        unchecked {
            lpTokenBalance = lpTokenBalance - reservedLPTokens;
        }
    }
}
