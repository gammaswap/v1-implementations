// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/rebalance/ExternalRebalanceStrategy.sol";
import "../../../interfaces/vault/strategies/IVaultStrategy.sol";
import "../base/VaultBaseLongStrategy.sol";

/// @title Vault External Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with UniswapV2
contract VaultExternalRebalanceStrategy is VaultBaseLongStrategy, ExternalRebalanceStrategy, IVaultStrategy {

    error InvalidRefType();
    error ExcessiveLPTokensReserved();

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_, address feeSource_,
        uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseLongStrategy(maxTotalApy_,
        blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev Update total interest charged except for reserved LP tokens
    /// @dev See {BaseStrategy-updateStore}.
    function updateStore(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply)
        internal virtual override(BaseStrategy,VaultBaseLongStrategy) returns(uint256 accFeeIndex, uint256 newBorrowedInvariant) {
        return super.updateStore(lastFeeIndex, borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply);
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

    /// @dev See {IVaultStrategy-_reserveLPTokens}.
    function _reserveLPTokens(uint256 tokenId, uint256 lpTokens, bool isReserve) external virtual override lock returns(uint256) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        if(_loan.refType == 3) revert InvalidRefType();

        updateLoan(_loan);

        if(isReserve) {
            uint256 lpTokenBalance = getAdjLPTokenBalance();

            // Revert if reserving all remaining CFMM LP tokens in pool
            if(lpTokens >= lpTokenBalance) revert ExcessiveLPTokensReserved();

            checkExpectedUtilizationRate(lpTokens, true);

            uint256 reservedLPTokens = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));

            s.setUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS), reservedLPTokens + lpTokens);
        } else {
            uint256 reservedLPTokens = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));

            lpTokens = GSMath.min(reservedLPTokens, lpTokens);
            unchecked {
                reservedLPTokens = reservedLPTokens - lpTokens;
            }

            s.setUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS), reservedLPTokens);
        }

        return lpTokens;
    }
}
