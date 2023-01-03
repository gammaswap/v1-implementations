// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LongStrategy.sol";
import "./CPMMBaseLongStrategy.sol";

contract CPMMLongStrategy is CPMMBaseLongStrategy, LongStrategy {

    constructor(uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseLongStrategy(_originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    function _getLatestCFMMReserves() public virtual override view returns(uint256[] memory reserves) {
        reserves = new uint256[](2);
        (reserves[0], reserves[1],) = ICPMM(s.cfmm).getReserves();
    }

}
