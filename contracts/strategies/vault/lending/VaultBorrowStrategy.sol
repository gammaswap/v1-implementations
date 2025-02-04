// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/lending/BorrowStrategy.sol";
import "@gammaswap/v1-core/contracts/strategies/rebalance/RebalanceStrategy.sol";
import "../base/VaultBaseRebalanceStrategy.sol";

/// @title Vault Borrow and Rebalance Strategy concrete implementation contract for Vault GammaPool Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BorrowStrategy and RebalanceStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract VaultBorrowStrategy is VaultBaseRebalanceStrategy, BorrowStrategy, RebalanceStrategy {

    /// @dev Initializes the contract by setting `mathLib`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_,
        address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseRebalanceStrategy(mathLib_,
        maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseBorrowStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

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
}
