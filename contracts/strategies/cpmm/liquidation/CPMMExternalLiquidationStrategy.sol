// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/liquidation/ExternalLiquidationStrategy.sol";
import "../base/CPMMBaseRebalanceStrategy.sol";

/// @title External Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice LiquidationStrategy implementation for Constant Product Market Maker that also allows external swaps (flash loans) during liquidations
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMExternalLiquidationStrategy is CPMMBaseRebalanceStrategy, ExternalLiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @dev Initializes the contract by setting `mathLib_`, `LTV_THRESHOLD`, `LIQUIDATION_FEE`,
    /// @dev `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint16 liquidationThreshold_, uint16 liquidationFeeThreshold_, uint256 maxTotalApy_,
        uint256 blocksPerYear_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_,
        uint80 maxApy_) CPMMBaseRebalanceStrategy(mathLib_, liquidationThreshold_, maxTotalApy_, blocksPerYear_,
        tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {

        LIQUIDATION_FEE = liquidationFeeThreshold_;
    }

    /// @dev returns liquidation fee threshold
    function _liquidationFee() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE;
    }
}
