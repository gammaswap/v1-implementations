// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../interfaces/rates/ILinearKinkedRateModel.sol";
import "../interfaces/rates/AbstractRateModel.sol";

abstract contract LinearKinkedRateModel is AbstractRateModel, ILinearKinkedRateModel {

    error BasRateGTMaxAPY();
    error OptimalUtilRate();

    uint64 immutable public override baseRate;
    uint64 immutable public override optimalUtilRate;
    uint64 immutable public override slope1;
    uint64 immutable public override slope2;

    constructor(uint64 _baseRate, uint64 _optimalUtilRate, uint64 _slope1, uint64 _slope2) {
        if(!(_optimalUtilRate > 0 && _optimalUtilRate < 1e18)){
            revert OptimalUtilRate();
        }
        baseRate = _baseRate;
        optimalUtilRate = _optimalUtilRate;
        slope1 = _slope1;
        slope2 = _slope2;
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256) {
        uint256 utilizationRate = calcUtilizationRate(lpInvariant, borrowedInvariant);
        if(utilizationRate == 0) {
            return 0;
        }
        if(utilizationRate <= optimalUtilRate) {
            uint256 variableRate = (utilizationRate * slope1) / optimalUtilRate;
            return baseRate + variableRate;
        } else {
            uint256 utilizationRateDiff = utilizationRate - optimalUtilRate;
            uint256 variableRate = (utilizationRateDiff * slope2) / (1e18 - optimalUtilRate);
            return baseRate + slope1 + variableRate;
        }
    }
}
