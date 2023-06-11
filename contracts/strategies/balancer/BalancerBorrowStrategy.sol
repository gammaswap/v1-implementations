// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/lending/BorrowStrategy.sol";
import "./base/BalancerBaseRebalanceStrategy.sol";

/// @title Borrow Strategy concrete implementation contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BorrowStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerBorrowStrategy is BalancerBaseRebalanceStrategy, BorrowStrategy {

    /// @dev Initialises the contract by setting `mathLib`, `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `origFee`, `baseRate`, `factor`, `maxApy`, and `_weight0`
    constructor(address mathLib_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 origFee_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_, uint256 weight0_) BalancerBaseRebalanceStrategy(mathLib_,
        ltvThreshold_, maxTotalApy_, blocksPerYear_, origFee_, baseRate_, factor_, maxApy_, weight0_) {
    }

    /// @dev See {BaseLongStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        (uint256 factor0, uint256 factor1) = getScalingFactors();
        uint256 numerator = s.CFMM_RESERVES[1] * factor1 * weight1 / weight0;
        return numerator * 1e18 / (s.CFMM_RESERVES[0] * factor0);
    }
}
