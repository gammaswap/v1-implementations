// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../libraries/storage/rates/LinearKinkedRateStorage.sol";
import "../interfaces/rates/ILinearKinkedRateModel.sol";
import "../interfaces/rates/AbstractRateModel.sol";

abstract contract LinearKinkedRateModel is AbstractRateModel, ILinearKinkedRateModel {

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        uint256 totalLp = lpBalance + lpBorrowed;
        if(totalLp == 0)
            return 0;

        LinearKinkedRateStorage.Store storage store = LinearKinkedRateStorage.store();
        uint256 utilizationRate = (lpBorrowed * store.ONE) / totalLp;
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
        return LinearKinkedRateStorage.store().baseRate;
    }

    function optimalUtilRate() external virtual override view returns(uint256) {
        return LinearKinkedRateStorage.store().optimalUtilRate;
    }

    function slope1() external virtual override view returns(uint256) {
        return LinearKinkedRateStorage.store().slope1;
    }

    function slope2() external virtual override view returns(uint256) {
        return LinearKinkedRateStorage.store().slope2;
    }
}
