// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/liquidation/ExternalLiquidationStrategy.sol";
import "../base/BalancerBaseRebalanceStrategy.sol";

/// @title External Liquidation Strategy concrete implementation contract for Balancer AMM
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice LiquidationStrategy implementation for Balancer AMM that also allows external swaps (flash loans) during liquidations
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerExternalLiquidationStrategy is BalancerBaseRebalanceStrategy, ExternalLiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @return EXTERNAL_SWAP_FEE - fees charged to flash loans
    uint256 immutable public EXTERNAL_SWAP_FEE;

    /// @dev Initializes the contract by setting `mathLib_`, `EXTERNAL_SWAP_FEE`, `LTV_THRESHOLD`, `LIQUIDATION_FEE`,
    /// @dev `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `baseRate`, `factor`, `maxApy`, and `weight0`
    constructor(address mathLib_, uint256 extSwapFee_, uint16 liquidationThreshold_, uint16 liquidationFeeThreshold_,
        uint256 maxTotalApy_, uint256 blocksPerYear_, uint64 baseRate_, uint80 factor_, uint80 maxApy_, uint256 weight0_)
        BalancerBaseRebalanceStrategy(mathLib_, liquidationThreshold_, maxTotalApy_, blocksPerYear_, 0, baseRate_,
        factor_, maxApy_, weight0_) {

        EXTERNAL_SWAP_FEE = extSwapFee_;
        LIQUIDATION_FEE = liquidationFeeThreshold_;
    }

    /// @return Returns the liquidation fee threshold.
    function _liquidationFee() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE;
    }

    /// @dev See {ExternalBaseStrategy-externalSwapFee}
    function externalSwapFee() internal view virtual override returns(uint256) {
        return EXTERNAL_SWAP_FEE;
    }
}
