// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/LongStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

/// @title Long Strategy concrete implementation contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LongStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerLongStrategy is BalancerBaseLongStrategy, LongStrategy {

    /// @dev Initialises the contract by setting `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `origFee`,
    /// @dev `baseRate`, `factor`, `maxApy`, and `_weight0`
    constructor(uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 originationFee_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_, uint256 weight0_) BalancerBaseLongStrategy(ltvThreshold_,
        maxTotalApy_, blocksPerYear_, originationFee_, baseRate_, factor_, maxApy_, weight0_) {
    }

    /// @dev See {BaseLongStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        (uint256 factor0, uint256 factor1) = getScalingFactors();
        uint256 numerator = s.CFMM_RESERVES[1] * factor1 * weight1 / weight0;
        return numerator * 1e18 / (s.CFMM_RESERVES[0] * factor0);
    }

    /// @dev See {ILongStrategy-calcDeltasToClose}.
    function calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId)
        external virtual override view returns(int256[] memory deltas) {

        return _calcDeltasToClose(tokensHeld, reserves, liquidity, collateralId);
    }

    /// @dev See {ILongStrategy-calcDeltasForRatio}.
    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio)
        external virtual override view returns(int256[] memory deltas) {

        return _calcDeltasForRatio(tokensHeld, reserves, ratio);
    }

    /// @dev See {LongStrategy-_calcDeltasForRatio}.
    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio)
        internal virtual override view returns(int256[] memory deltas) {

        deltas = new int256[](2);
    }

    /// @dev See {LongStrategy-_calcDeltasForWithdrawal}.
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves,
        uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {

        deltas = new int256[](2);
    }

}
