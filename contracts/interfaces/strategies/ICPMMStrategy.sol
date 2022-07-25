// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ICPMMStrategy {
    function factory() external view returns(address);
    function initCodeHash() external view returns(bytes32);
    function tradingFee1() external view returns(uint16);
    function tradingFee2() external view returns(uint16);
}
