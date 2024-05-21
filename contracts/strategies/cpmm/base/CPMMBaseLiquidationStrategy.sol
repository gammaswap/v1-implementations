// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/base/BaseLiquidationStrategy.sol";
import "./CPMMBaseRebalanceStrategy.sol";

/// @title Base Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BaseLiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
abstract contract CPMMBaseLiquidationStrategy is BaseLiquidationStrategy, CPMMBaseRebalanceStrategy {

    /// @dev Thrown when address trying to liquidate is not LIQUIDATOR
    error NotLiquidator();

    /// @dev Address of liquidator
    address immutable public LIQUIDATOR;

    /// @dev Initializes the contract by setting `liquidator`, `mathLib`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `tradingFee1`, `tradingFee2`, `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address liquidator_, address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_,
        address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseRebalanceStrategy(mathLib_,
        maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
        LIQUIDATOR = liquidator_;
    }

    /// @dev If LIQUIDATOR is set then check that address calling liquidation function is LIQUIDATOR
    function _checkLiquidator(address _sender) internal override virtual {
        if(LIQUIDATOR != address(0) && LIQUIDATOR != _sender) revert NotLiquidator();
    }
}
