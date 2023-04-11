// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/LongStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

/// @title Long Strategy concrete implementation contract for Balancer Weighted Pools
/// @notice Sets up variables used by LongStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerLongStrategy is BalancerBaseLongStrategy, LongStrategy {

    /// @dev Initialises the contract by setting `_ltvThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_originationFee`, `_baseRate`, `_factor`, `_maxApy`, and `_weight0`
    constructor(uint16 _ltvThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint24 _originationFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0)
        BalancerBaseLongStrategy(_ltvThreshold, _maxTotalApy, _blocksPerYear, _originationFee, _baseRate, _factor, _maxApy, _weight0) {
    }

    /// @dev See {BaseLongStrategy.getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        (uint256 factor0, uint256 factor1) = getScalingFactors();
        uint256 numerator = s.CFMM_RESERVES[1] * factor1 * weight1 / weight0;
        return numerator * 1e18 / (s.CFMM_RESERVES[0] * factor0);
    }
}
