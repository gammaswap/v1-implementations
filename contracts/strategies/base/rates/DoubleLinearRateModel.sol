// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../../libraries/storage/rates/DoubleLinearRateStorage.sol";
import "../../../interfaces/strategies/base/rates/IDoubleLinearRateModel.sol";
import "../BaseStrategy.sol";

abstract contract DoubleLinearRateModel is BaseStrategy, IDoubleLinearRateModel {

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        DoubleLinearRateStorage.Store storage store = DoubleLinearRateStorage.store();
        uint256 utilizationRate = (lpBorrowed * store.ONE) / (lpBalance + lpBorrowed);
        if(utilizationRate <= store.optimalUtilRate) {
            uint256 variableRate = (utilizationRate * store.slope1) / store.optimalUtilRate;
            return (store.baseRate + variableRate);
        } else {
            uint256 utilizationRateDiff = utilizationRate - store.optimalUtilRate;
            uint256 variableRate = (utilizationRateDiff * store.slope2) / (store.ONE - store.optimalUtilRate);
            return (store.baseRate + store.slope1 + variableRate);
        }
    }

    function baseRate() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().baseRate;
    }

    function optimalUtilRate() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().optimalUtilRate;
    }

    function slope1() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().slope1;
    }

    function slope2() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().slope2;
    }
}
