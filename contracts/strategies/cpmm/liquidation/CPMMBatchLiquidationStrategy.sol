// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/liquidation/BatchLiquidationStrategy.sol";
import "../base/CPMMBaseRebalanceStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMBatchLiquidationStrategy is CPMMBaseRebalanceStrategy, BatchLiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @dev Initializes the contract by setting `LTV_THRESHOLD`, `LIQUIDATION_FEE`, `MAX_TOTAL_APY`,
    /// @dev `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint16 liquidationThreshold_, uint16 liquidationFee_, uint256 maxTotalApy_,
        uint256 blocksPerYear_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_,
        uint80 maxApy_) CPMMBaseRebalanceStrategy(mathLib_, liquidationThreshold_, maxTotalApy_, blocksPerYear_, 0,
        tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {

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
