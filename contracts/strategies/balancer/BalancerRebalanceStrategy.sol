// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/lending/RepayStrategy.sol";
import "./BalancerBaseRebalanceStrategy.sol";

/// @title Rebalance Strategy concrete implementation contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by RebalanceStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerRebalanceStrategy is BalancerBaseRebalanceStrategy, RebalanceStrategy {

    /// @dev Initialises the contract by setting `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `origFee`,
    /// @dev `baseRate`, `factor`, `maxApy`, and `_weight0`
    constructor(address mathLib_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 originationFee_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_, uint256 weight0_) BalancerBaseRebalanceStrategy(mathLib_, ltvThreshold_,
        maxTotalApy_, blocksPerYear_, originationFee_, baseRate_, factor_, maxApy_, weight0_) {
    }
}
