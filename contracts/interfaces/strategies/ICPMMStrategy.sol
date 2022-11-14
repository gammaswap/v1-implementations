// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface ICPMMStrategy {
    function tradingFee1() external view returns(uint16);
    function tradingFee2() external view returns(uint16);
}
