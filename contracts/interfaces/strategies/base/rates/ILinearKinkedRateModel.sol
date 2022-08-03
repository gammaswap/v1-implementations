// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ILinearKinkedRateModel {
    function baseRate() external view returns(uint256);
    function optimalUtilRate() external view returns(uint256);
    function slope1() external view returns(uint256);
    function slope2() external view returns(uint256);
}
