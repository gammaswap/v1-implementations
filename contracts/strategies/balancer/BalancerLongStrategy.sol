// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LongStrategy.sol";
import "./BalancerBaseLongStrategy.sol";

/**
 * @title Long Strategy concrete implementation contract for Balancer Weighted Pools
 * @author JakeXBT (https://github.com/JakeXBT)
 * @notice Sets up variables used by LongStrategy and defines internal functions specific to Balancer Weighted Pools
 * @dev This implementation was specifically designed to work with Balancer
 */
contract BalancerLongStrategy is BalancerBaseLongStrategy, LongStrategy {

    /**
     * @dev Initialises the contract by setting `_ltvThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_originationFee`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
     */
    constructor(uint16 _ltvThreshold, uint256 _blocksPerYear, uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseLongStrategy(_ltvThreshold, _blocksPerYear, _originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }
    
    /**
     * @dev Get the price associated with the Balancer pool.
     * @param cfmm The address of the Balancer pool.
     */
    function _getCFMMPrice(address cfmm) public virtual view returns(uint256 price) {
        uint128[] memory reserves = getPoolReserves(cfmm);
        uint256[] memory weights = getWeights(cfmm);
        price = (reserves[1] * weights[0]) / (reserves[0] * weights[1]);
    }

    /** 
     * @dev Get latest reserve quantities in Balancer pool through public function.
     */
    function _getLatestCFMMReserves() public virtual override view returns(uint256[] memory reserves) {
        reserves = new uint256[](2);

        uint128[] memory poolReserves = new uint128[](2);
        poolReserves = getPoolReserves(s.cfmm);

        reserves[0] = uint256(poolReserves[0]);
        reserves[1] = uint256(poolReserves[1]);
    }

}
