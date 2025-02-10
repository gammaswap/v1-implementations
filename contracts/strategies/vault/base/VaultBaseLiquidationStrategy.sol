// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../cpmm/base/CPMMBaseLiquidationStrategy.sol";
import "./VaultBaseRepayStrategy.sol";

/// @title Vault Base Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BaseLiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
abstract contract VaultBaseLiquidationStrategy is CPMMBaseLiquidationStrategy, VaultBaseRepayStrategy {

    /// @dev See {BaseStrategy-accrueBorrowedInvariant}.
    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual
        override(BaseStrategy,VaultBaseRepayStrategy) view returns(uint256) {
        return super.accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
    }

    /// @dev Update loan's liquidity debt with interest charged except when loan is of refType 3
    /// @dev See {BaseLongStrategy-updateLoanLiquidity}.
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual
        override(BaseLongStrategy,VaultBaseRepayStrategy) returns(uint256 liquidity) {
        return super.updateLoanLiquidity(_loan, accFeeIndex);
    }

    /// @dev See {BaseStrategy-checkExpectedUtilizationRate}.
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override(BaseStrategy,VaultBaseRepayStrategy) view {
        return super.checkExpectedUtilizationRate(lpTokens, isLoan);
    }

    /// @dev See {BaseRepayStrategy-payLoanLiquidity}.
    function payLoanLiquidity(uint256 liquidity, uint256 loanLiquidity, LibStorage.Loan storage _loan) internal virtual
        override(BaseRepayStrategy,VaultBaseRepayStrategy) returns(uint256 lpTokenPrincipal, uint256 remainingLiquidity) {
        return super.payLoanLiquidity(liquidity, loanLiquidity, _loan);
    }
}
