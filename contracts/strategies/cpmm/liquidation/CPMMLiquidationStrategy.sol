// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/liquidation/SingleLiquidationStrategy.sol";
import "../base/CPMMBaseRebalanceStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMLiquidationStrategy is CPMMBaseRebalanceStrategy, SingleLiquidationStrategy {

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 tradingFee1_, uint16 tradingFee2_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_) CPMMBaseRebalanceStrategy(mathLib_, maxTotalApy_,
        blocksPerYear_, tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {
    }
}
