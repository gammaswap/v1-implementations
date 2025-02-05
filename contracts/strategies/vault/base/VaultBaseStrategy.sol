// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/base/BaseStrategy.sol";

/// @title Vault Base Strategy abstract contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for Constant Product Market Maker
/// @dev This implementation was specifically designed to work with UniswapV2. Inherits Rate Model
abstract contract VaultBaseStrategy is BaseStrategy {

    using LibStorage for LibStorage.Storage;

    /// @dev enum indices for storage fields saved for balancer AMMsx
    enum StorageIndexes { RESERVED_BORROWED_INVARIANT, RESERVED_LP_TOKENS }

    /// @dev Update pool invariant, LP tokens borrowed plus interest, interest rate index, and last block update
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @param borrowedInvariant - liquidity invariant borrowed in the GammaPool
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @return accFeeIndex - liquidity invariant lpTokenBalance represents
    /// @return newBorrowedInvariant - borrowed liquidity invariant after interest accrual
    function updateStore(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply)
        internal virtual override returns(uint256 accFeeIndex, uint256 newBorrowedInvariant) {
        // Accrue interest to borrowed liquidity
        uint256 reservedBorrowedInvariant = s.getUint256(uint256(StorageIndexes.RESERVED_BORROWED_INVARIANT));
        borrowedInvariant = borrowedInvariant - reservedBorrowedInvariant;
        newBorrowedInvariant = accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex) + reservedBorrowedInvariant;
        s.BORROWED_INVARIANT = uint128(newBorrowedInvariant);

        // Convert borrowed liquidity to corresponding CFMM LP tokens using current conversion rate
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(newBorrowedInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
        uint256 lpInvariant = convertLPToInvariant(s.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        // Update GammaPool's interest rate index and update last block updated
        accFeeIndex = s.accFeeIndex * lastFeeIndex / 1e18;
        s.accFeeIndex = uint80(accFeeIndex);
        s.emaUtilRate = uint32(_calcUtilRateEma(calcUtilizationRate(lpInvariant, newBorrowedInvariant), s.emaUtilRate,
            GSMath.max(block.number - s.LAST_BLOCK_NUMBER, s.emaMultiplier)));
        s.LAST_BLOCK_NUMBER = uint40(block.number);
    }

    /// @dev Revert if lpTokens withdrawal causes utilization rate to go over 98%
    /// @param lpTokens - lpTokens expected to change utilization rate
    /// @param isLoan - true if lpTokens are being borrowed
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override view {
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 reservedLPTokens = s.getUint256(uint256(StorageIndexes.RESERVED_LP_TOKENS));

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
        uint256 reservedLPTokens = s.getUint256(uint256(StorageIndexes.RESERVED_LP_TOKENS));
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        lpTokenBalance = lpTokenBalance >= reservedLPTokens ? lpTokenBalance - reservedLPTokens : 0;
    }
}
