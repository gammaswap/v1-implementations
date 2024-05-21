// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/liquidation/BatchLiquidationStrategy.sol";
import "../base/CPMMBaseLiquidationStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMBatchLiquidationStrategy is CPMMBaseLiquidationStrategy, BatchLiquidationStrategy {

    /// @dev Initializes the contract by setting `liquidator`, `mathLib`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `tradingFee1`, `tradingFee2`,`feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address liquidator_, address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_,
        uint24 tradingFee2_, address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_)
        CPMMBaseLiquidationStrategy(liquidator_, mathLib_, maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_,
        feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {

    }

    /// @dev See {BatchLiquidationStrategy-_calcMaxCollateralNotMktImpact}.
    function _calcMaxCollateralNotMktImpact(uint128[] memory tokensHeld, uint128[] memory reserves) internal override virtual returns(uint256) {
        // [A * P + B] / [2 * sqrt(P)]
        // [(A * reserve1 / reserve0) + B] / (2 * sqrt(reserve1/reserve0)
        // [(A * reserve1 / reserve0) + B] / [2 * sqrt(reserve1)/sqrt(reserve0)]
        // [(A * reserve1 / reserve0) + B] * sqrt(reserve0) / [2 * sqrt(reserve1)]
        // [(A * reserve1 + B * reserve0) / reserve0] * sqrt(reserve0) / [2 * sqrt(reserve1)]
        // [A * reserve1 * sqrt(reserve0) + B * reserve0 * sqrt(reserve0)] / [2 * reserve0 * sqrt(reserve1)]
        // [A * sqrt(reserve1) * sqrt(reserve0)] / [2 * reserve0] + [B * reserve0] / [2 * sqrt(reserve0) * sqrt(reserve1)]
        // (A * L_hat / reserve0 + B * reserve0 / L_hat) / 2
        uint256 lastCFMMInvariant = GSMath.sqrt(uint256(reserves[0]) * reserves[1]);
        uint256 leftVal = uint256(tokensHeld[0]) * lastCFMMInvariant / reserves[0];
        uint256 rightVal = uint256(tokensHeld[1]) * reserves[0] / lastCFMMInvariant;
        return (leftVal + rightVal) / 2;
    }
}
