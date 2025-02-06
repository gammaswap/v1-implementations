// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/base/BaseRepayStrategy.sol";
import "./VaultBaseRebalanceStrategy.sol";

/// @title Abstract base contract for Vault Repay Strategy implementation
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All functions here are internal, external functions implemented in BaseLongStrategy as part of ILongStrategy implementation
/// @dev Only defines common functions that would be used by all contracts that repay liquidity
abstract contract VaultBaseRepayStrategy is BaseRepayStrategy, VaultBaseRebalanceStrategy {

    using LibStorage for LibStorage.Storage;

    /// @dev Update total interest charged except for reserved LP tokens
    /// @dev See {BaseStrategy-updateStore}.
    function updateStore(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply)
        internal virtual override(BaseStrategy,VaultBaseRebalanceStrategy) returns(uint256 accFeeIndex, uint256 newBorrowedInvariant) {
        return super.updateStore(lastFeeIndex, borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    /// @dev Update loan's liquidity debt with interest charged except when loan is of refType 3
    /// @dev See {BaseLongStrategy-updateLoanLiquidity}.
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual
        override(BaseLongStrategy,VaultBaseRebalanceStrategy) returns(uint256 liquidity) {
        return super.updateLoanLiquidity(_loan, accFeeIndex);
    }

    /// @dev See {BaseStrategy-checkExpectedUtilizationRate}.
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override(BaseStrategy,VaultBaseRebalanceStrategy) view {
        return super.checkExpectedUtilizationRate(lpTokens, isLoan);
    }

    /// @dev Account for paid liquidity debt in loan and account for refType 3 loans
    /// @dev See {BaseRepayStrategy-payLoanLiquidity}.
    function payLoanLiquidity(uint256 liquidity, uint256 loanLiquidity, LibStorage.Loan storage _loan) internal virtual
        override returns(uint256 lpTokenPrincipal, uint256 remainingLiquidity) {
        uint256 loanLpTokens = _loan.lpTokens; // Loan's CFMM LP token principal
        uint256 loanInitLiquidity = _loan.initLiquidity; // Loan's liquidity invariant principal

        // Calculate loan's CFMM LP token principal repaid
        lpTokenPrincipal = GSMath.min(loanLpTokens, convertInvariantToLP(liquidity, loanLpTokens, loanLiquidity));

        uint256 initLiquidityPaid = GSMath.min(loanInitLiquidity, liquidity * loanInitLiquidity / loanLiquidity);

        uint256 _paidLiquidity = GSMath.max(_loan.liquidity, remainingLiquidity);

        unchecked {
            // Calculate loan's outstanding liquidity invariant principal after liquidity payment
            loanInitLiquidity = loanInitLiquidity - initLiquidityPaid;

            // Update loan's outstanding CFMM LP token principal
            loanLpTokens = loanLpTokens - lpTokenPrincipal;

            // Calculate loan's outstanding liquidity invariant after liquidity payment
            remainingLiquidity = loanLiquidity - GSMath.min(loanLiquidity, liquidity);

            _paidLiquidity = _paidLiquidity - remainingLiquidity;
        }

        // Can't be less than min liquidity to avoid rounding issues
        if (remainingLiquidity > 0 && remainingLiquidity < minBorrow()) revert MinBorrow();

        // If fully paid, free memory to save gas
        if(remainingLiquidity == 0) { // lpTokens should be zero
            _loan.rateIndex = 0;
            _loan.px = 0;
            _loan.lpTokens = 0;
            _loan.initLiquidity = 0;
            _loan.liquidity = 0;
            if(loanLpTokens > 0) lpTokenPrincipal += loanLpTokens; // cover rounding issues
            // pay whole liquidity
        } else {
            _loan.lpTokens = uint128(loanLpTokens);
            _loan.initLiquidity = uint128(loanInitLiquidity);
            _loan.liquidity = uint128(remainingLiquidity);
            // calc paid liquidity
        }

        if(_loan.refType == 3 && _paidLiquidity > 0) {
            uint256 reservedBorrowedInvariant = GSMath.max(s.getUint256(uint256(StorageIndexes.RESERVED_BORROWED_INVARIANT)), _paidLiquidity);
            unchecked {
                reservedBorrowedInvariant = reservedBorrowedInvariant - _paidLiquidity;
            }
            s.setUint256(uint256(StorageIndexes.RESERVED_BORROWED_INVARIANT), reservedBorrowedInvariant);
        }
    }
}
