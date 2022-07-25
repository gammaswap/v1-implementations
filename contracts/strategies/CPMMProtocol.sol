// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/strategies/IProtocol.sol";
import "../libraries/storage/strategies/CPMMStrategyStorage.sol";
import "../libraries/storage/rates/DoubleLinearRateStorage.sol";
import "../libraries/storage/GammaPoolStorage.sol";
import "../libraries/storage/ProtocolStorage.sol";
import "../libraries/PoolAddress.sol";
import "./cpmm/CPMMLongStrategy.sol";
import "./cpmm/CPMMShortStrategy.sol";
import "../interfaces/strategies/ICPMMStrategy.sol";
import "../interfaces/strategies/base/rates/IDoubleLinearRateModel.sol";

contract CPMMProtocol is IProtocol, ICPMMStrategy, IDoubleLinearRateModel {

    //If this class takes a delegated call, this should not be here

    //0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    //0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303 SushiSwap
    constructor(address _factory, uint24 _protocol, bytes32 _initCodeHash, uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _optimalRate, uint256 _slope1, uint256 _slope2) {
        ProtocolStorage.init(_protocol, address(new CPMMLongStrategy()), address(new CPMMShortStrategy()), msg.sender);
        CPMMStrategyStorage.init(_factory, _initCodeHash, _tradingFee1, _tradingFee2);
        DoubleLinearRateStorage.init(_baseRate, _optimalRate, _slope1, _slope2);
        //(uint256 baseRate, uint256 optimalRate, uint256 slope1, uint256 slope2)
    }

    function protocol() external virtual override view returns(uint24) {
        return ProtocolStorage.store().protocol;
    }

    function longStrategy() external virtual override view returns(address) {
        return ProtocolStorage.store().longStrategy;
    }

    function shortStrategy() external virtual override view returns(address) {
        return ProtocolStorage.store().shortStrategy;
    }

    //this is the factory of the protocol (Not all protocols have a factory)
    function factory() external virtual override view returns(address) {
        return CPMMStrategyStorage.store().factory;
    }

    function initCodeHash() external virtual override view returns(bytes32) {
        return CPMMStrategyStorage.store().initCodeHash;
    }

    function tradingFee1() external virtual override view returns(uint16) {
        return CPMMStrategyStorage.store().tradingFee1;
    }

    function tradingFee2() external virtual override view returns(uint16) {
        return CPMMStrategyStorage.store().tradingFee2;
    }

    function baseRate() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().baseRate;
    }

    function optimalUtilRate() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().optimalUtilRate;
    }

    function slope1() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().slope1;
    }

    function slope2() external virtual override view returns(uint256) {
        return DoubleLinearRateStorage.store().slope2;
    }

    /*function parameters() external virtual override returns(bytes32 memory) {

    }/**/

    //delegated call //TODO:.use params struct here. We'll be able to pass other values that can set the
    function initialize() external virtual override {
        /*
            we only need to pass the protocolFactory, If this is a delegated call then we have access to
            factory and protocol through GammaPoolStorage.
            we have no need for initCodeHash or protocolFactory, since those are used for validation, nothing else
            However we want to set:
                -interest rate parameters.
                -strategy parameters (trading fees)
            We might need to have different interest rate model parameters for different protocols
            maybe set it in the constructor and we pass it as a struct back to here?
            //we can pass bytes32 calldata data and convert here, that way we can define our interest rate model however we want
        */
        //CPMMStrategyStorage.init(factory, protocolFactory, protocol, new bytes32());
    }

    function isContract(address account) internal virtual view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens, bytes32 key){
        require(isContract(_cfmm) == true, 'not contract');
        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        CPMMStrategyStorage.Store storage store = CPMMStrategyStorage.store();
        require(_cfmm == PoolAddress.computeAddress(store.factory,keccak256(abi.encodePacked(tokens[0], tokens[1])),store.initCodeHash), 'bad protocol');
        key = PoolAddress.getPoolKey(_cfmm, ProtocolStorage.store().protocol);
    }
}
