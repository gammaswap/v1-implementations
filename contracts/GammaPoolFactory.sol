// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./GammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/strategies/IProtocol.sol";

contract GammaPoolFactory is IGammaPoolFactory{

    event PoolCreated(address indexed pool, address indexed cfmm, uint24 indexed protocolId, address protocol, uint256 count);

    address public override feeToSetter;
    address public override owner;
    address private feeTo;
    uint256 private fee = 5 * (10**16); //5% of borrowed interest gains by default

    mapping(uint24 => address) public override getProtocol;//there's a protocol
    mapping(bytes32 => address) public override getPool;//all GS Pools addresses can be predetermined
    mapping(uint24 => bool) public override isProtocolRestricted;//a protocol creation can be restricted

    address[] public allPools;

    Parameters private _params;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
    }

    function parameters() external virtual override view returns(address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        _cfmm = _params.cfmm;
        _protocolId = _params.protocolId;
        _tokens = _params.tokens;
        _protocol = _params.protocol;
    }

    function allPoolsLength() external virtual override view returns (uint) {
        return allPools.length;
    }

    function addProtocol(address protocol) external virtual override {
        require(msg.sender == owner,'FORBIDDEN');
        require(IProtocol(protocol).protocol() > 0,'0_PROT');
        require(getProtocol[IProtocol(protocol).protocol()] == address(0), 'PROT_EXISTS');
        getProtocol[IProtocol(protocol).protocol()] = protocol;
    }

    function removeProtocol(uint24 protocol) external virtual override {
        require(msg.sender == owner,'FORBIDDEN');
        getProtocol[protocol] = address(0);
    }

    function setIsProtocolRestricted(uint24 protocol, bool isRestricted) external virtual override {
        require(msg.sender == owner,'FORBIDDEN');
        isProtocolRestricted[protocol] = isRestricted;
    }

    function createPool(CreatePoolParams calldata params) external virtual override returns (address pool) {
        uint24 protocolId = params.protocol;

        require(getProtocol[protocolId] != address(0), 'PROT_NOT_SET');
        require(isProtocolRestricted[protocolId] == false || msg.sender == owner, 'RESTRICTED');

        address protocol = getProtocol[protocolId];

        address cfmm = params.cfmm;

        _params = Parameters({cfmm: cfmm, protocolId: protocolId, tokens: new address[](0), protocol: protocol});

        bytes32 key;
        (_params.tokens, key) = IProtocol(protocol).validateCFMM(params.tokens, cfmm);

        require(getPool[key] == address(0), 'POOL_EXISTS');
        pool = address(new GammaPool{salt: key}());//This is fine because the address is tied to the factory contract here. If the factory didn't create it, it will have a different address.
        delete _params;

        getPool[key] = pool;
        allPools.push(pool);
        emit PoolCreated(pool, cfmm, protocolId, protocol, allPools.length);
    }

    function feeInfo() external virtual override view returns(address _feeTo, uint _fee) {
        _feeTo = feeTo;
        _fee = fee;
    }

    function setFee(uint _fee) external {
        require(msg.sender == feeToSetter,'FORBIDDEN');
        fee = _fee;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter,'FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter,'FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

}
