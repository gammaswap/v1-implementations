// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/cpmm/CPMMShortStrategy.sol";

contract TestCPMMShortStrategy is CPMMShortStrategy {

    using LibStorage for LibStorage.Storage;

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMShortStrategy(_baseRate, _factor, _maxApy) {
    }

    function initialize(address cfmm, address[] calldata tokens) external virtual {
        s.initialize(msg.sender, cfmm, tokens);
    }

    function testCalcDeposits(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) public virtual view returns(uint256[] memory amounts, address payee) {
        (amounts, payee) = calcDepositAmounts(amountsDesired, amountsMin);
    }

    function testCheckOptimalAmt(uint256 amountOptimal, uint256 amountMin) public virtual pure returns(uint8){
        checkOptimalAmt(amountOptimal, amountMin);
        return 3;
    }

    function testGetReserves(address cfmm) public virtual view returns(uint128[] memory reserves){
        return getReserves(cfmm);
    }
}
