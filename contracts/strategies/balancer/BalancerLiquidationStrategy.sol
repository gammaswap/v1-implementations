// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@gammaswap/v1-core/contracts/strategies/LiquidationStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

/**
 * @title Liquidation Strategy concrete implementation contract for Balancer Weighted Pools
 * @author JakeXBT (https://github.com/JakeXBT)
 * @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to Balancer Weighted Pools
 * @dev This implementation was specifically designed to work with Balancer
 */
contract BalancerLiquidationStrategy is BalancerBaseLongStrategy, LiquidationStrategy {
    uint16 immutable public LIQUIDATION_FEE_THRESHOLD;

    /**
     * @dev Initialises the contract by setting `_liquidationThreshold`, `_liquidationFeeThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
     */
    constructor(uint16 _liquidationThreshold, uint16 _liquidationFeeThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseLongStrategy(_liquidationThreshold, _maxTotalApy, _blocksPerYear, 0, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
        LIQUIDATION_FEE_THRESHOLD = _liquidationFeeThreshold;
    }

    /**
     * @return Returns the liquidation fee threshold.
     */
    function liquidationFeeThreshold() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE_THRESHOLD;
    }
}
