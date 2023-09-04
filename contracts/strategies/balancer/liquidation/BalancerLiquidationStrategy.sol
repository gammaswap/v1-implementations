// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@gammaswap/v1-core/contracts/strategies/liquidation/SingleLiquidationStrategy.sol";
import "@gammaswap/v1-core/contracts/strategies/liquidation/BatchLiquidationStrategy.sol";
import "../base/BalancerBaseRebalanceStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerLiquidationStrategy is BalancerBaseRebalanceStrategy, SingleLiquidationStrategy, BatchLiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @dev Initialises the contract by setting `mathLib_`, `LTV_THRESHOLD`, `LIQUIDATION_FEE`, `MAX_TOTAL_APY`,
    /// @dev `BLOCKS_PER_YEAR`, `baseRate`, `factor`, `maxApy`, and `weight0`
    constructor(address mathLib_, uint16 liquidationThreshold_, uint16 liquidationFee_, uint256 maxTotalApy_, uint256 blocksPerYear_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_, uint256 weight0_) BalancerBaseRebalanceStrategy(mathLib_, liquidationThreshold_,
        maxTotalApy_, blocksPerYear_, 0, baseRate_, factor_, maxApy_, weight0_) {

        LIQUIDATION_FEE = liquidationFee_;
    }

    /// @dev See {BaseLiquidationStrategy-_liquidationFee}.
    function _liquidationFee() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE;
    }

    /// @dev See {BatchLiquidationStrategy-_calcMaxCollateralNotMktImpact}.
    function _calcMaxCollateralNotMktImpact(uint128[] memory tokensHeld, uint128[] memory reserves) internal override virtual returns(uint256) {
        return 0;
    }
}
