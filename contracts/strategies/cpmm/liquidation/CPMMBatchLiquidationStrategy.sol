// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/liquidation/BatchLiquidationStrategy.sol";
import "../base/CPMMBaseRebalanceStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMBatchLiquidationStrategy is CPMMBaseRebalanceStrategy, BatchLiquidationStrategy {

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 tradingFee1_, uint16 tradingFee2_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_) CPMMBaseRebalanceStrategy(mathLib_, maxTotalApy_,
        blocksPerYear_, tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {
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
