// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/rebalance/ExternalRebalanceStrategy.sol";
import "../base/CPMMBaseLongStrategy.sol";

/// @title External Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMExternalRebalanceStrategy is CPMMBaseLongStrategy, ExternalRebalanceStrategy {

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `feeSource`,
    /// @dev `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 tradingFee1_, address feeSource_,
        uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseLongStrategy(maxTotalApy_,
        blocksPerYear_, tradingFee1_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }
}
