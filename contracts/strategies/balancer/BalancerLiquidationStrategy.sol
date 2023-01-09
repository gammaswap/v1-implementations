// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LiquidationStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

contract BalancerLiquidationStrategy is BalancerBaseLongStrategy, LiquidationStrategy {
    uint16 immutable public LIQUIDATION_FEE_THRESHOLD;

    constructor(uint16 _liquidationThreshold, uint16 _liquidationFeeThreshold, uint256 _blocksPerYear, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseLongStrategy(_liquidationThreshold, _blocksPerYear, 0, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
        LIQUIDATION_FEE_THRESHOLD = _liquidationFeeThreshold;
    }

    function liquidationFeeThreshold() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE_THRESHOLD;
    }
}
