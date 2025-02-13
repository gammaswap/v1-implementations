// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../cpmm/base/CPMMBaseRebalanceStrategy.sol";
import "./VaultBaseLongStrategy.sol";

/// @title Vault Base Rebalance Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BaseRebalanceStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
abstract contract VaultBaseRebalanceStrategy is CPMMBaseRebalanceStrategy, VaultBaseLongStrategy {

    /// @dev See {BaseStrategy-accrueBorrowedInvariant}.
    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual
        override(BaseStrategy,VaultBaseLongStrategy) view returns(uint256) {
        return super.accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
    }

    /// @dev Update loan's liquidity debt with interest charged except when loan is of refType 3
    /// @dev See {BaseLongStrategy-updateLoanLiquidity}.
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual
        override(BaseLongStrategy,VaultBaseLongStrategy) returns(uint256 liquidity) {
        return super.updateLoanLiquidity(_loan, accFeeIndex);
    }

    /// @dev See {BaseStrategy-checkExpectedUtilizationRate}.
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override(BaseStrategy,VaultBaseLongStrategy) view {
        return super.checkExpectedUtilizationRate(lpTokens, isLoan);
    }
}
