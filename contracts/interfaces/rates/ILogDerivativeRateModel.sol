pragma solidity ^0.8.0;

interface ILogDerivativeRateModel {
    function baseRate() external view returns(uint256);
    function factor() external view returns(uint256);
    function maxApy() external view returns(uint256);
}
