// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./deployers/TestBaseStrategyDeployer.sol";
import "./deployers/TestShortStrategyDeployer.sol";
import "./deployers/TestLongStrategyDeployer.sol";
import "./deployers/TestShortERC4626Deployer.sol";
import "./deployers/cpmm/TestCPMMBaseStrategyDeployer.sol";
import "./deployers/cpmm/TestCPMMShortStrategyDeployer.sol";
import "./deployers/cpmm/TestCPMMShortStrategyDeployer2.sol";

contract TestStrategyFactory {

    address public cfmm;
    uint24 public protocolId;
    address[] public tokens;
    address public protocol;
    address public strategy;

    constructor(address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        cfmm = _cfmm;
        protocolId = _protocolId;
        tokens = _tokens;
        protocol = _protocol;
    }

    function parameters() external virtual view returns (address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        _cfmm = cfmm;
        _protocolId = protocolId;
        _tokens = tokens;
        _protocol = protocol;
    }

    function createStrategy(address deployer) public virtual returns(bool) {
        (bool success, bytes memory data) = deployer.delegatecall(abi.encodeWithSignature("createPool()"));
        require(success && data.length > 0);
        strategy = abi.decode(data, (address));
        return true;
    }
}
