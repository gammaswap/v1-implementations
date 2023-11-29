// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/liquidation/ExternalLiquidationStrategy.sol";
import "../base/CPMMBaseRebalanceStrategy.sol";

/// @title External Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice LiquidationStrategy implementation for Constant Product Market Maker that also allows external swaps (flash loans) during liquidations
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMExternalLiquidationStrategy is CPMMBaseRebalanceStrategy, ExternalLiquidationStrategy {

    /// @dev Initializes the contract by setting `mathLib_`,`MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`,
    /// @dev `feeSource_`, `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 tradingFee1_, address feeSource_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_) CPMMBaseRebalanceStrategy(mathLib_, maxTotalApy_, blocksPerYear_,
        tradingFee1_, feeSource_, baseRate_, factor_, maxApy_) {
    }
}
