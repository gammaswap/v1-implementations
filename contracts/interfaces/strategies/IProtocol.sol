// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IProtocol {
    function protocol() external view returns(uint24);
    function protocolFactory() external view returns(address);
    function factory() external view returns(address);
    function initCodeHash() external view returns(bytes32);
    function longStrategy() external view returns(address);
    function shortStrategy() external view returns(address);
    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens, bytes32 key);
}
