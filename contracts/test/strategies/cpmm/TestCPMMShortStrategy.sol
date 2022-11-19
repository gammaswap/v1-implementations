// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/cpmm/CPMMShortStrategy.sol";

contract TestCPMMShortStrategy is CPMMShortStrategy {

    constructor(uint256 _baseRate, uint256 _factor, uint256 _maxApy)
        CPMMShortStrategy(_baseRate, _factor, _maxApy) {
    }

    function initialize(address cfmm, address[] calldata tokens) external virtual {
        GammaPoolStorage.init(cfmm, tokens);
    }

    function testCalcDeposits(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) public virtual view returns(uint256[] memory amounts, address payee) {
        (amounts, payee) = calcDepositAmounts(GammaPoolStorage.store(), amountsDesired, amountsMin);
    }

    function testCheckOptimalAmt(uint256 amountOptimal, uint256 amountMin) public virtual pure returns(uint8){
        checkOptimalAmt(amountOptimal, amountMin);
        return 3;
    }

    function testGetReserves(address cfmm) public virtual view returns(uint256[] memory reserves){
        return getReserves(cfmm);
    }
}
