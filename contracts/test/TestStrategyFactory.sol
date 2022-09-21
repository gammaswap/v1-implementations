pragma solidity ^0.8.0;

import "./TestBaseStrategy.sol";

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

    function createBaseStrategy() public virtual returns(bool) {
        strategy = address(new TestBaseStrategy());
        return true;
    }
}
