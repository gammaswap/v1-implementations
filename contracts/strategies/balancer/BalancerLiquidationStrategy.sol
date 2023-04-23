// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/LiquidationStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerLiquidationStrategy is BalancerBaseLongStrategy, LiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @dev Initialises the contract by setting `_liquidationThreshold`, `_liquidationFee`, `_maxTotalApy`, `_blocksPerYear`, `_baseRate`, `_factor`, `_maxApy`, and `_weight0`
    constructor(uint16 _liquidationThreshold, uint16 _liquidationFee, uint256 _maxTotalApy, uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0)
        BalancerBaseLongStrategy(_liquidationThreshold, _maxTotalApy, _blocksPerYear, 0, _baseRate, _factor, _maxApy, _weight0) {
        LIQUIDATION_FEE = _liquidationFee;
    }

    /// @return Returns the liquidation fee threshold.
    function _liquidationFee() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE;
    }
}
