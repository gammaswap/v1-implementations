// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ISendLiquidityCallback {
    function sendLiquidityCallback(address to, uint256 amount) external;
}