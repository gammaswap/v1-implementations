// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface ILinearKinkedRateModel {
    function baseRate() external view returns(uint256);
    function optimalUtilRate() external view returns(uint256);
    function slope1() external view returns(uint256);
    function slope2() external view returns(uint256);
}
