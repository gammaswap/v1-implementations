// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LongStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

contract BalancerLongStrategy is BalancerBaseLongStrategy, LongStrategy {

    constructor(uint16 _ltvThreshold, uint256 _blocksPerYear, uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseLongStrategy(_ltvThreshold, _blocksPerYear, _originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    function _getCFMMPrice(address cfmm) public virtual view returns(uint256 price) {
        uint128[] memory reserves = getPoolReserves(cfmm);
        uint256[] memory weights = getWeights(cfmm);
        price = (reserves[1] * weights[0]) / (reserves[0] * weights[1]);
    }

    function _getLatestCFMMReserves(address cfmm) public virtual override view returns(uint256[] memory reserves) {
        // TODO: This is already implemented in BalancerBaseStrategy but for uint128 type for use elsewhere
        // Do we need to do this casting? Is there an easier way?
        reserves = new uint256[](2);

        uint128[] memory poolReserves = new uint128[](2);
        poolReserves = getPoolReserves(cfmm);

        reserves[0] = uint256(poolReserves[0]);
        reserves[1] = uint256(poolReserves[1]);
    }

}
