// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface ILogDerivativeRateModel {
    function baseRate() external view returns(uint256);
    function factor() external view returns(uint256);
    function maxApy() external view returns(uint256);
}
