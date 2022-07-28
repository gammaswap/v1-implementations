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

    //0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    //0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303 SushiSwap
    address public immutable owner;

    constructor(address gsFactory, address _factory, uint24 _protocol, bytes32 _initCodeHash, uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _optimalUtilRate, uint256 _slope1, uint256 _slope2) {
        owner = gsFactory;
        CPMMStrategyStorage.init(_factory, _initCodeHash, _tradingFee1, _tradingFee2);
        DoubleLinearRateStorage.init(_baseRate, _optimalUtilRate, _slope1, _slope2);
        bytes memory sParams = strategyParams();
        bytes memory rParams = rateParams();
        //address longStrategy = address(new CPMMLongStrategy(sParams,rParams));
        //address shortStrategy = address(new CPMMShortStrategy(sParams,rParams));
        ProtocolStorage.init(_protocol,
            address(new CPMMLongStrategy(sParams,rParams)),
            address(new CPMMShortStrategy(sParams,rParams)),
            msg.sender);
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

    function strategyParams() internal virtual view returns(bytes memory) {
        CPMMStrategyStorage.Store storage sStore = CPMMStrategyStorage.store();
        return abi.encode(CPMMStrategyStorage.Store({
            factory: sStore.factory,
            initCodeHash: sStore.initCodeHash,
            tradingFee1: sStore.tradingFee1,
            tradingFee2: sStore.tradingFee2, isSet: false }));
    }

    function rateParams() internal virtual view returns(bytes memory) {
        DoubleLinearRateStorage.Store storage rStore = DoubleLinearRateStorage.store();
        return abi.encode(DoubleLinearRateStorage.Store({
            ONE: 10**18,
            YEAR_BLOCK_COUNT: 2252571,
            baseRate: rStore.baseRate,
            optimalUtilRate: rStore.optimalUtilRate,
            slope1: rStore.slope1,
            slope2: rStore.slope2,
            isSet: false }));
    }

    function parameters() external virtual override view returns(bytes memory pParams, bytes memory sParams, bytes memory rParams) {
        ProtocolStorage.Store storage pStore = ProtocolStorage.store();
        pParams = abi.encode(ProtocolStorage.Store({
            protocol: pStore.protocol,
            longStrategy: pStore.longStrategy,
            shortStrategy: pStore.shortStrategy,
            owner: pStore.owner, isSet: false}));

        CPMMStrategyStorage.Store storage sStore = CPMMStrategyStorage.store();
        sParams = abi.encode(CPMMStrategyStorage.Store({
            factory: sStore.factory,
            initCodeHash: sStore.initCodeHash,
            tradingFee1: sStore.tradingFee1,
            tradingFee2: sStore.tradingFee2, isSet: false}));

        DoubleLinearRateStorage.Store storage rStore = DoubleLinearRateStorage.store();
        rParams = abi.encode(DoubleLinearRateStorage.Store({
            ONE: 10**18,
            YEAR_BLOCK_COUNT: 2252571,
            baseRate: rStore.baseRate,
            optimalUtilRate: rStore.optimalUtilRate,
            slope1: rStore.slope1,
            slope2: rStore.slope2,
            isSet: false}));
    }

    //delegated call only
    function initialize(bytes calldata pData, bytes calldata sData, bytes calldata rData) external virtual override returns(bool) {
        require(msg.sender == owner);//This checks the factory can only call this. It's a delegate call from the smart contract. So it's called from the context of the GammaPool, which means message sender is factory

        ProtocolStorage.Store memory pParams = abi.decode(pData, (ProtocolStorage.Store));
        ProtocolStorage.init(pParams.protocol, pParams.longStrategy, pParams.shortStrategy, pParams.owner);

        CPMMStrategyStorage.Store memory sParams = abi.decode(sData, (CPMMStrategyStorage.Store));
        CPMMStrategyStorage.init(sParams.factory, sParams.initCodeHash, sParams.tradingFee1, sParams.tradingFee2);

        DoubleLinearRateStorage.Store memory rParams = abi.decode(rData, (DoubleLinearRateStorage.Store));
        DoubleLinearRateStorage.init(rParams.baseRate, rParams.optimalUtilRate, rParams.slope1, rParams.slope2);

        return true;
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
        require(_cfmm == PoolAddress.calcAddress(store.factory,keccak256(abi.encodePacked(tokens[0], tokens[1])),store.initCodeHash), 'bad protocol');
        key = PoolAddress.getPoolKey(_cfmm, ProtocolStorage.store().protocol);
    }
}
