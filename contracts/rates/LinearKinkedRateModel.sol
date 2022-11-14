// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../interfaces/rates/ILinearKinkedRateModel.sol";
import "../interfaces/rates/AbstractRateModel.sol";

abstract contract LinearKinkedRateModel is AbstractRateModel, ILinearKinkedRateModel {

    uint256 immutable public override baseRate;
    uint256 immutable public override optimalUtilRate;
    uint256 immutable public override slope1;
    uint256 immutable public override slope2;

    constructor(uint256 _baseRate, uint256 _optimalUtilRate, uint256 _slope1, uint256 _slope2) {
        baseRate = _baseRate;
        optimalUtilRate = _optimalUtilRate;
        slope1 = _slope1;
        slope2 = _slope2;
    }

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        uint256 totalLp = lpBalance + lpBorrowed;
        if(totalLp == 0)
            return 0;

        uint256 utilizationRate = (lpBorrowed * 10**18) / totalLp;
        if(utilizationRate <= optimalUtilRate) {
            uint256 variableRate = (utilizationRate * slope1) / optimalUtilRate;
            return (baseRate + variableRate);
        } else {
            uint256 utilizationRateDiff = utilizationRate - optimalUtilRate;
            uint256 variableRate = (utilizationRateDiff * slope2) / (10**18 - optimalUtilRate);
            return (baseRate + slope1 + variableRate);
        }
    }
}
