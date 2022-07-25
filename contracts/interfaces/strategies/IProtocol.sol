// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IProtocol {
    function initialize(bytes calldata protData, bytes calldata stratData, bytes calldata rateData) external returns(bool);
    function parameters() external view returns(bytes memory,bytes memory,bytes memory);
    function protocol() external view returns(uint24);
    function longStrategy() external view returns(address);
    function shortStrategy() external view returns(address);
    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens, bytes32 key);
}
