// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../../strategies/cpmm/CPMMShortStrategy.sol";

contract TestCPMMShortStrategy2  is CPMMShortStrategy {

    constructor() {
        GammaPoolStorage.init();
    }

    function testCalcDeposits(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) public virtual view returns(uint256[] memory amounts, address payee) {
        (amounts, payee) = calcDepositAmounts(GammaPoolStorage.store(), amountsDesired, amountsMin);
    }
}
