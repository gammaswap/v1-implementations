// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IWETH {
    // Deposit ether to get wrapped ether
    function deposit() external payable;

    // Withdraw wrapped ether to get ether
    function withdraw(uint256) external;

}