// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../interfaces/rates/ILogDerivativeRateModel.sol";
import "../interfaces/rates/AbstractRateModel.sol";
import "../libraries/Math.sol";

abstract contract LogDerivativeRateModel is AbstractRateModel, ILogDerivativeRateModel {

    uint64 immutable public override baseRate;
    uint80 immutable public override factor;
    uint80 immutable public override maxApy;

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy) {
        baseRate = _baseRate;
        factor = _factor;
        maxApy = _maxApy;
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256) {
        uint256 utilizationRate = calcUtilizationRate(lpInvariant, borrowedInvariant);
        uint256 utilizationRateSquare = utilizationRate**2;
        uint256 denominator = 10**36 - utilizationRateSquare + 1;// add 1 so that it never becomes 0
        return Math.min(baseRate + factor * utilizationRateSquare / denominator, maxApy);
    }
}