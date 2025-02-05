// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../cpmm/base/CPMMBaseLongStrategy.sol";
import "./VaultBaseStrategy.sol";

/// @title Vault Base Long Strategy abstract contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for CPMM that need access to loans
/// @dev This implementation was specifically designed to work with UniswapV2.
abstract contract VaultBaseLongStrategy is CPMMBaseLongStrategy, VaultBaseStrategy {

    /// @dev Update total interest charged except for reserved LP tokens
    /// @dev See {BaseStrategy-updateStore}.
    function updateStore(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply)
        internal virtual override(BaseStrategy,VaultBaseStrategy) returns(uint256 accFeeIndex, uint256 newBorrowedInvariant) {
        return super.updateStore(lastFeeIndex, borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    /// @dev Update loan's liquidity debt with interest charged except when loan is of refType 3
    /// @dev See {BaseLongStrategy-updateLoanLiquidity}.
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual override returns(uint256 liquidity) {
        uint256 rateIndex = _loan.rateIndex;
        liquidity = rateIndex == 0 ? 0 : _loan.refType == 3 ? _loan.liquidity : (_loan.liquidity * accFeeIndex) / rateIndex;
        _loan.liquidity = uint128(liquidity);
        _loan.rateIndex = uint80(accFeeIndex);
    }

    /// @dev See {BaseStrategy-checkExpectedUtilizationRate}.
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override(BaseStrategy,VaultBaseStrategy) view {
        return super.checkExpectedUtilizationRate(lpTokens, isLoan);
    }
}
