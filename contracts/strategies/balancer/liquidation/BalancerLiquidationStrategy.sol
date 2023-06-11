// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/liquidation/SingleLiquidationStrategy.sol";
import "@gammaswap/v1-core/contracts/strategies/liquidation/BatchLiquidationStrategy.sol";
import "../base/BalancerBaseLongStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerLiquidationStrategy is BalancerBaseLongStrategy, SingleLiquidationStrategy, BatchLiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @dev Initialises the contract by setting `LTV_THRESHOLD`, `LIQUIDATION_FEE`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `baseRate`, `factor`, `maxApy`, and `weight0`
    constructor(uint16 liquidationThreshold_, uint16 liquidationFee_, uint256 maxTotalApy_, uint256 blocksPerYear_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_, uint256 weight0_) BalancerBaseLongStrategy(liquidationThreshold_,
        maxTotalApy_, blocksPerYear_, 0, baseRate_, factor_, maxApy_, weight0_) {

        LIQUIDATION_FEE = liquidationFee_;
    }

    /// @dev See {BaseLiquidationStrategy-_liquidationFee}.
    function _liquidationFee() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE;
    }
}
