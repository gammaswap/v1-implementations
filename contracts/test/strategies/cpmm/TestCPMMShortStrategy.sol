// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/cpmm/CPMMShortStrategy.sol";

contract TestCPMMShortStrategy is CPMMShortStrategy {

    constructor(uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _optimalUtilRate, uint256 _slope1, uint256 _slope2)
        CPMMShortStrategy(_tradingFee1, _tradingFee2, _baseRate, _optimalUtilRate, _slope1, _slope2) {
    }

    function initialize(address cfmm, uint24 protocolId, address protocol, address[] calldata tokens) external virtual {
        GammaPoolStorage.init(cfmm, protocolId, protocol, tokens, address(this), address(this));
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
