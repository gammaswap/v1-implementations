// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LiquidationStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

contract BalancerLiquidationStrategy is BalancerBaseLongStrategy, LiquidationStrategy {

    constructor(uint16 _tradingFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseLongStrategy(0, _tradingFee, _baseRate, _factor, _maxApy) {
    }
}
