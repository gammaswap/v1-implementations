// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './GammaPool.sol';
import './PositionManager.sol';
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/IProtocolModule.sol";
//import "hardhat/console.sol";

contract GammaPoolFactory is IGammaPoolFactory{

    address public override feeTo;
    address public override feeToSetter;
    address public override owner;
    uint256 public override fee = 5 * (10**16); //5% of borrowed interest gains by default

    mapping(uint24 => address) public override getModule;
    mapping(uint24 => mapping(address => mapping(address => address))) public override getPool;
    address[] public allPools;

    /// @inheritdoc IGammaPoolFactory
    Parameters public override parameters;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
    }

    function allPoolsLength() external virtual override view returns (uint) {
        return allPools.length;
    }

    function addModule(uint24 protocol, address module) external virtual override {
        require(msg.sender == owner, 'FACTORY.addModule: FORBIDDEN');
        getModule[protocol] = module;
    }

    function createPool(address tokenA, address tokenB, uint24 protocol) external virtual override returns (address pool) {
        require(getModule[protocol] != address(0), 'FACTORY.createPool: PROTOCOL_NOT_SET');
        require(tokenA != tokenB, 'FACTORY.createPool: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0) && token1 != address(0), 'FACTORY.createPool: ZERO_ADDRESS');
        require(getPool[protocol][token0][token1] == address(0), 'FACTORY.createPool: POOL_EXISTS'); // single check is sufficient
        address cfmm = IProtocolModule(getModule[protocol]).getCFMM(token0, token1);//TODO: What if the pool doesn't exist yet? Doesn't matter. No one will be able to use it anyways. And if someone creates it, it will be usable
        parameters = Parameters({factory: address(this), token0: token0, token1: token1, protocol: protocol, cfmm: cfmm});
        pool = address(new GammaPool{salt: keccak256(abi.encode(token0, token1, protocol))}());
        delete parameters;
        getPool[protocol][token0][token1] = pool;
        getPool[protocol][token1][token0] = pool; // populate mapping in the reverse direction
        allPools.push(pool);
        //emit PoolCreated(token0, token1, protocol, pool, allPools.length);/**/
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
}
