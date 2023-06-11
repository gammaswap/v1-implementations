// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/liquidation/ExternalLiquidationStrategy.sol";
import "../base/CPMMBaseLongStrategy.sol";

/// @title External Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice LiquidationStrategy implementation for Constant Product Market Maker that also allows external swaps (flash loans) during liquidations
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMExternalLiquidationStrategy is CPMMBaseLongStrategy, ExternalLiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @return EXTERNAL_SWAP_FEE - fees charged to flash loans
    uint256 immutable public EXTERNAL_SWAP_FEE;

    /// @dev Initializes the contract by setting `EXTERNAL_SWAP_FEE`, `LTV_THRESHOLD`, `LIQUIDATION_FEE`,
    /// @dev `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(uint256 extSwapFee_, uint16 liquidationThreshold_, uint16 liquidationFeeThreshold_,
        uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_,
        uint80 factor_, uint80 maxApy_) CPMMBaseLongStrategy(liquidationThreshold_, maxTotalApy_,
        blocksPerYear_, 0, tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {

        EXTERNAL_SWAP_FEE = extSwapFee_;
        LIQUIDATION_FEE = liquidationFeeThreshold_;
    }

    /// @dev returns liquidation fee threshold
    function _liquidationFee() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE;
    }

    /// @dev See {ExternalBaseStrategy-externalSwapFee}
    function externalSwapFee() internal view virtual override returns(uint256) {
        return EXTERNAL_SWAP_FEE;
    }
}
