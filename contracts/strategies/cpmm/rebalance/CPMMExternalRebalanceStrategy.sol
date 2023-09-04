// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@gammaswap/v1-core/contracts/strategies/rebalance/ExternalRebalanceStrategy.sol";
import "../base/CPMMBaseLongStrategy.sol";

/// @title External Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMExternalRebalanceStrategy is CPMMBaseLongStrategy, ExternalRebalanceStrategy {

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `baseRate`, `factor`, and `maxApy`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 tradingFee1_, uint16 tradingFee2_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_) CPMMBaseLongStrategy(maxTotalApy_, blocksPerYear_,
        tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {
    }
}
