// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./deployers/TestBaseStrategyDeployer.sol";
import "./deployers/TestShortStrategyDeployer.sol";
import "./deployers/cpmm/TestCPMMBaseStrategyDeployer.sol";

contract TestStrategyFactory {

    address public cfmm;
    uint24 public protocolId;
    address[] public tokens;
    address public protocol;
    address public strategy;

    address public baseDeployer;
    address public shortDeployer;
    address public cpmmBaseDeployer;

    constructor(address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        cfmm = _cfmm;
        protocolId = _protocolId;
        tokens = _tokens;
        protocol = _protocol;
        baseDeployer = address(new TestBaseStrategyDeployer());
        shortDeployer = address(new TestShortStrategyDeployer());
        cpmmBaseDeployer = address(new TestCPMMBaseStrategyDeployer());
    }

    function parameters() external virtual view returns (address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        _cfmm = cfmm;
        _protocolId = protocolId;
        _tokens = tokens;
        _protocol = protocol;
    }

    function createBaseStrategy() public virtual returns(bool) {
        (bool success, bytes memory data) = baseDeployer.delegatecall(abi.encodeWithSignature("createPool()"));
        require(success && data.length > 0);
        strategy = abi.decode(data, (address));
        return true;
    }

    function createShortStrategy() public virtual returns(bool) {
        (bool success, bytes memory data) = shortDeployer.delegatecall(abi.encodeWithSignature("createPool()"));
        require(success && data.length > 0);
        strategy = abi.decode(data, (address));
        return true;
    }

    function createCPMMBaseStrategy() public virtual returns(bool) {
        (bool success, bytes memory data) = cpmmBaseDeployer.delegatecall(abi.encodeWithSignature("createPool()"));
        require(success && data.length > 0);
        strategy = abi.decode(data, (address));
        return true;
    }
}
