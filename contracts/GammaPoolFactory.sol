// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./GammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/strategies/IProtocol.sol";

contract GammaPoolFactory is IGammaPoolFactory{

    event PoolCreated(address indexed pool, address indexed cfmm, uint24 indexed protocol, uint256 count);

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

    function parameters() external virtual override view returns(address _cfmm, uint24 _protocol, address[] memory _tokens, address _longStrategy, address _shortStrategy) {
        _tokens = _params.tokens;
        _protocol = _params.protocol;
        _cfmm = _params.cfmm;
        _longStrategy = _params.longStrategy;
        _shortStrategy = _params.shortStrategy;
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
        uint24 protocol = params.protocol;

        require(getProtocol[protocol] != address(0), 'PROT_NOT_SET');
        require(isProtocolRestricted[protocol] == false || msg.sender == owner, 'RESTRICTED');

        IProtocol _protocol = IProtocol(getProtocol[protocol]);

        address cfmm = params.cfmm;

        _params = Parameters({cfmm: cfmm, protocol: protocol, tokens: new address[](0), longStrategy: _protocol.longStrategy(), shortStrategy: _protocol.shortStrategy()});

        bytes32 key;
        (_params.tokens, key) = _protocol.validateCFMM(params.tokens, cfmm);

        require(getPool[key] == address(0), 'POOL_EXISTS');
        pool = address(new GammaPool{salt: key}());//This is fine because the address is tied to the factory contract here. If the factory didn't create it, it will have a different address.
        delete _params;

        getPool[key] = pool;
        allPools.push(pool);
        emit PoolCreated(pool, cfmm, protocol, allPools.length);
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
