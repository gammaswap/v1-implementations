// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './GammaPool.sol';
import './PositionManager.sol';
import "./interfaces/IGammaPoolFactory.sol";
//import "hardhat/console.sol";

contract GammaPoolFactory is IGammaPoolFactory{

    address public positionManager;
    address public feeTo;
    address public feeToSetter;
    address public owner;
    uint256 public fee = 5 * (10**16); //5% of borrowed interest gains by default

    mapping(uint24 => address) public getRouter;
    mapping(uint24 => mapping(address => mapping(address => address))) public getPool;
    address[] public allPools;

    /// @inheritdoc IGammaPoolFactory
    Parameters public override parameters;

    constructor(address _feeToSetter, address _positionManager) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        positionManager = _positionManager;
        owner = msg.sender;
    }

    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }

    function addRouter(uint24 protocolId, address protocolRouter) external {
        require(msg.sender == owner, 'FACTORY.addRouter: FORBIDDEN');
        getRouter[protocolId] = protocolRouter;
    }

    function createPool(address tokenA, address tokenB, uint24 protocol) external returns (address pool) {
        require(getRouter[protocol] != address(0), 'FACTORY.createPool: PROTOCOL_NOT_SET');
        require(tokenA != tokenB, 'FACTORY.createPool: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0) && token1 != address(0), 'FACTORY.createPool: ZERO_ADDRESS');
        require(getPool[protocol][token0][token1] == address(0), 'FACTORY.createPool: POOL_EXISTS'); // single check is sufficient
        parameters = Parameters({factory: address(this), token0: token0, token1: token1, protocol: protocol});
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
