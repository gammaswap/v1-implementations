// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../strategies/cpmm/CPMMShortStrategy.sol";


contract TestCPMMShortStrategy is CPMMShortStrategy {
    constructor(bytes memory _sParams, bytes memory _rParams) CPMMShortStrategy(_sParams, _rParams) {
    }

    function testCheckOptimalAmt(uint256 amountOptimal, uint256 amountMin) external {
        checkOptimalAmt(amountOptimal, amountMin);
    }

    function testGetReserves(address cfmm) external returns(uint256[] memory reserves) {
        getReserves(cfmm);
    }

    function testDepositToCFMM(address cfmm, uint256[] memory amounts, address to) external {
        console.log(to.balance);
        depositToCFMM(cfmm, amounts, to);
    }
}
