// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LongStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

contract BalancerLongStrategy is BalancerBaseLongStrategy, LongStrategy {

    constructor(uint16 _originationFee, uint16 _tradingFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy, address _vault)
        BalancerBaseLongStrategy(_originationFee, _tradingFee, _baseRate, _factor, _maxApy, _vault) {
    }

    function _getCFMMPrice(address cfmm) public virtual override view returns(uint256 price) {
        uint128[] memory reserves = getPoolReserves(cfmm);
        uint256[] memory weights = getWeights(cfmm);
        price = (reserves[1] * weights[0]) / (reserves[0] * weights[1]);
    }

}
