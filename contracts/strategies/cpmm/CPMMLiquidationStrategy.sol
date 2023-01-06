// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LiquidationStrategy.sol";
import "./CPMMLongStrategy.sol";

contract CPMMLiquidationStrategy is CPMMBaseLongStrategy, LiquidationStrategy {

    constructor(uint256 _blocksPerYear, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseLongStrategy(_blocksPerYear, 0, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }
}
