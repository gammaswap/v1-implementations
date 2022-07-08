// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './GammaPool.sol';
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/IProtocolModule.sol";
//import "hardhat/console.sol";

contract GammaPoolFactory is IGammaPoolFactory{

    address public override feeTo;
    address public override feeToSetter;
    address public override owner;
    uint256 public override fee = 5 * (10**16); //5% of borrowed interest gains by default

    mapping(uint24 => address) public override getModule;//there's a module per protocol
    mapping(bytes32 => address) public override getPool;//all GS Pools addresses can be predetermined
    mapping(uint24 => bool) public override isProtocolRestricted;//a protocol creation can be restricted

    address[] public allPools;

    Parameters public parameters;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
    }

    function getParameters() external virtual override view returns(address factory, address[] memory tokens, uint24 protocol, address cfmm) {
        factory = address(this);
        tokens = parameters.tokens;
        protocol = parameters.protocol;
        cfmm = parameters.cfmm;
    }

    function allPoolsLength() external virtual override view returns (uint) {
        return allPools.length;
    }

    function addModule(address module) external virtual override {
        require(msg.sender == owner, 'FACTORY.addModule: FORBIDDEN');
        uint24 protocol = IProtocolModule(module).protocol();
        require(protocol > 0, 'FACTORY.addModule: ZERO_PROTOCOL');
        require(getModule[protocol] == address(0), 'FACTORY.addModule: PROTOCOL_ALREADY_EXISTS');
        getModule[protocol] = module;
    }

    function setIsProtocolRestricted(uint24 protocol, bool isRestricted) external virtual override {
        require(msg.sender == owner, 'FACTORY.setIsProtocolRestricted: FORBIDDEN');
        isProtocolRestricted[protocol] = isRestricted;
    }

    function createPool(Parameters calldata params) external virtual override returns (address pool) {
        require(getModule[params.protocol] != address(0), 'FACTORY.createPool: PROTOCOL_NOT_SET');
        require(isProtocolRestricted[params.protocol] == false || msg.sender == owner, 'FACTORY.createPool: PROTOCOL_RESTRICTED');
        require(params.cfmm != address(0), 'FACTORY.createPool: ZERO_ADDRESS');
        require(isContract(params.cfmm) == true, 'FACTORY.createPool: CFMM_DOES_NOT_EXIST');

        IProtocolModule module = IProtocolModule(getModule[params.protocol]);
        address[] memory tokens = module.validateCFMM(params.tokens, params.cfmm);
        bytes32 key = module.getKey(params.cfmm);//TODO: The parameters have to be tied to it. That way if someone creates this pool for us. The pool must have the right parameters.
        //Maybe the protocol should be the module address. That way it is tied to the module.
        //Someone could create it and not add the right parameters. So you need to decompose the address into the parameters
        //you initialize it by passing the parameters and check that the parameters can be compiled into the address. That's how you
        //know those are the right parameters

        parameters = Parameters({tokens: tokens, protocol: params.protocol, cfmm: params.cfmm});
        pool = address(new GammaPool{salt: key}());//This is fine because the address is tied to the factory contract here. If the factory didn't create it, it will have a different address.
        delete parameters;

        getPool[key] = pool;
        allPools.push(pool);
        //emit PoolCreated(token0, token1, protocol, pool, allPools.length);
    }

    function setFee(uint _fee) external {
        require(msg.sender == feeToSetter, 'FACTORY.setFee: FORBIDDEN');
        fee = _fee;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'FACTORY.setFeeTo: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'FACTORY.setFeeToSetter: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
}
