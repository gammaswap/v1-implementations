// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ITransfers {

    function WETH() external view returns (address);

    function clearToken(address token, uint256 minAmt, address to) external payable;

    function refundETH() external payable;

    function unwrapWETH(uint256 minAmt, address to) external payable;

}