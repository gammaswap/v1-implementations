// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './GammaPool2.sol';
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/IProtocolModule.sol";
//import "hardhat/console.sol";

contract GammaPoolFactory is IGammaPoolFactory{

    event PoolCreated(address indexed pool, address indexed cfmm, uint24 indexed protocol, uint256 count);

    address public override feeToSetter;
    address public override owner;
    address private feeTo;
    uint256 private fee = 5 * (10**16); //5% of borrowed interest gains by default

    mapping(uint24 => address) public override getModule;//there's a module per protocol
    mapping(bytes32 => address) public override getPool;//all GS Pools addresses can be predetermined
    mapping(uint24 => bool) public override isProtocolRestricted;//a protocol creation can be restricted

    address[] public allPools;

    address[] private tokens;
    address private cfmm;
    address private module;
    uint24 private protocol;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
    }

    function getParameters() external virtual override view returns(address[] memory _tokens, uint24 _protocol, address _cfmm, address _module) {
        _tokens = tokens;
        _protocol = protocol;
        _cfmm = cfmm;
        _module = module;
    }

    function allPoolsLength() external virtual override view returns (uint) {
        return allPools.length;
    }

    function addModule(address module) external virtual override {
        require(msg.sender == owner);//'FACTORY.addModule: FORBIDDEN');
        require(IProtocolModule(module).protocol() > 0);//'FACTORY.addModule: ZERO_PROTOCOL');
        require(getModule[IProtocolModule(module).protocol()] == address(0));
        getModule[IProtocolModule(module).protocol()] = module;/**/
    }

    function setIsProtocolRestricted(uint24 _protocol, bool isRestricted) external virtual override {
        require(msg.sender == owner);//'FACTORY.setIsProtocolRestricted: FORBIDDEN');
        isProtocolRestricted[_protocol] = isRestricted;
    }

    function createPool(Parameters calldata params) external virtual override returns (address pool) {
        require(getModule[params.protocol] != address(0), 'GPF: NOT_SET');
        require(isProtocolRestricted[params.protocol] == false || msg.sender == owner, 'GPF: RESTRICTED');

        IProtocolModule _module = IProtocolModule(getModule[params.protocol]);
        bytes32 key;
        (tokens, key) = _module.validateCFMM(params.tokens, params.cfmm);

        require(getPool[key] == address(0), 'GPF: EXISTS');
        //Maybe the protocol should be the module address. That way it is tied to the module.
        //Someone could create it and not add the right parameters. So you need to decompose the address into the parameters
        //you initialize it by passing the parameters and check that the parameters can be compiled into the address. That's how you
        //know those are the right parameters

        cfmm = params.cfmm;
        protocol = params.protocol;
        module = address(_module);
        pool = address(new GammaPool2{salt: key}());//This is fine because the address is tied to the factory contract here. If the factory didn't create it, it will have a different address.
        cfmm = address(0);
        protocol = 0;
        module = address(0);
        delete tokens;

        getPool[key] = pool;
        allPools.push(pool);
        emit PoolCreated(pool, params.cfmm, params.protocol, allPools.length);
    }

    function feeInfo() external virtual override view returns(address _feeTo, uint _fee) {
        _feeTo = feeTo;
        _fee = fee;
    }

    function setFee(uint _fee) external {
        require(msg.sender == feeToSetter);//'FACTORY.setFee: FORBIDDEN');
        fee = _fee;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter);//'FACTORY.setFeeTo: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter);//'FACTORY.setFeeToSetter: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

}
