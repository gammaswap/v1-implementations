// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
pragma abicoder v2;

import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "@gammaswap/v1-core/contracts/protocols/AbstractProtocol.sol";
import "../libraries/storage/strategies/CPMMStrategyStorage.sol";
import "../libraries/storage/rates/LinearKinkedRateStorage.sol";
import "../interfaces/strategies/ICPMMStrategy.sol";
import "../interfaces/rates/ILinearKinkedRateModel.sol";

contract CPMMProtocol is AbstractProtocol, ICPMMStrategy, ILinearKinkedRateModel {

    error NotContract();
    error BadProtocol();
    //0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    //0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303 SushiSwap

    struct CPMMProtocolParams {
        address _factory;
        bytes32 _initCodeHash;
        uint16 _tradingFee1;
        uint16 _tradingFee2;
        uint256 _baseRate;
        uint256 _optimalUtilRate;
        uint256 _slope1;
        uint256 _slope2;
    }

    constructor(address gsFactory, uint24 _protocol, bytes memory pData, address longStrategy, address shortStrategy) AbstractProtocol(gsFactory, _protocol, longStrategy, shortStrategy) {
        CPMMProtocolParams memory params = abi.decode(pData, (CPMMProtocolParams));
        CPMMStrategyStorage.init(params._factory, params._initCodeHash, params._tradingFee1, params._tradingFee2);
        LinearKinkedRateStorage.init(params._baseRate, params._optimalUtilRate, params._slope1, params._slope2);
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
        return LinearKinkedRateStorage.store().baseRate;
    }

    function optimalUtilRate() external virtual override view returns(uint256) {
        return LinearKinkedRateStorage.store().optimalUtilRate;
    }

    function slope1() external virtual override view returns(uint256) {
        return LinearKinkedRateStorage.store().slope1;
    }

    function slope2() external virtual override view returns(uint256) {
        return LinearKinkedRateStorage.store().slope2;
    }

    function strategyParams() internal virtual override view returns(bytes memory sParams) {
        CPMMStrategyStorage.Store storage sStore = CPMMStrategyStorage.store();
        sParams = abi.encode(CPMMStrategyStorage.Store({
        factory: sStore.factory,
        initCodeHash: sStore.initCodeHash,
        tradingFee1: sStore.tradingFee1,
        tradingFee2: sStore.tradingFee2, isSet: false}));
    }

    function rateParams() internal virtual override view returns(bytes memory rParams) {
        LinearKinkedRateStorage.Store storage rStore = LinearKinkedRateStorage.store();
        rParams = abi.encode(LinearKinkedRateStorage.Store({
        ONE: 10**18,
        YEAR_BLOCK_COUNT: 2252571,
        baseRate: rStore.baseRate,
        optimalUtilRate: rStore.optimalUtilRate,
        slope1: rStore.slope1,
        slope2: rStore.slope2,
        isSet: false}));
    }

    function initializeStrategyParams(bytes calldata sData) internal virtual override {
        CPMMStrategyStorage.Store memory sParams = abi.decode(sData, (CPMMStrategyStorage.Store));
        CPMMStrategyStorage.init(sParams.factory, sParams.initCodeHash, sParams.tradingFee1, sParams.tradingFee2);
    }

    function initializeRateParams(bytes calldata rData) internal virtual override {
        LinearKinkedRateStorage.Store memory rParams = abi.decode(rData, (LinearKinkedRateStorage.Store));
        LinearKinkedRateStorage.init(rParams.baseRate, rParams.optimalUtilRate, rParams.slope1, rParams.slope2);
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens) {
        //require(isContract(_cfmm) == true, "not contract");
        if(!isContract(_cfmm)) {
            revert NotContract();
        }

        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        CPMMStrategyStorage.Store storage store = CPMMStrategyStorage.store();
        if(_cfmm != AddressCalculator.calcAddress(store.factory,keccak256(abi.encodePacked(tokens[0], tokens[1])),store.initCodeHash)) {
            revert BadProtocol();
        }
        //require(_cfmm == AddressCalculator.calcAddress(store.factory,keccak256(abi.encodePacked(tokens[0], tokens[1])),store.initCodeHash), "bad protocol");
    }
}
