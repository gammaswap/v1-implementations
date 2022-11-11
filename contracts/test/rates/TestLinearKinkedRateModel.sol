// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../rates/LinearKinkedRateModel.sol";

contract TestLinearKinkedRateModel is LinearKinkedRateModel {
    constructor(uint256 baseRate, uint256 optimalUtilRate, uint256 slope1, uint256 slope2) {
        LinearKinkedRateStorage.init(baseRate, optimalUtilRate, slope1, slope2);
    }

    function testCalcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) public virtual view returns(uint256) {
        return calcBorrowRate(lpBalance, lpBorrowed);
    }
}
