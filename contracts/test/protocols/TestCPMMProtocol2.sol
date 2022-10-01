// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../libraries/storage/strategies/CPMMStrategyStorage.sol";
import "./TestCPMMProtocol.sol";

contract TestCPMMProtocol2 {
    address public protocol;

    constructor(address _protocol) {
        protocol = _protocol;
    }

    function testInitializeStrategyParams(bytes calldata sData) public virtual {
        protocol.delegatecall(abi.encodeWithSelector(TestCPMMProtocol(protocol).testInitializeStrategyParams.selector, sData));
    }

    function getStrategyParams() public virtual view returns(bytes memory sParams) {
        CPMMStrategyStorage.Store storage sStore = CPMMStrategyStorage.store();
        sParams = abi.encode(CPMMStrategyStorage.Store({
        factory: sStore.factory,
        initCodeHash: sStore.initCodeHash,
        tradingFee1: sStore.tradingFee1,
        tradingFee2: sStore.tradingFee2, isSet: sStore.isSet }));
    }

    function testInitializeRateParams(bytes calldata sData) public virtual {
        protocol.delegatecall(abi.encodeWithSelector(TestCPMMProtocol(protocol).testInitializeRateParams.selector, sData));
    }

    function getRateParams() public virtual view returns(bytes memory rParams) {
        LinearKinkedRateStorage.Store storage rStore = LinearKinkedRateStorage.store();
        rParams = abi.encode(LinearKinkedRateStorage.Store({
        ONE: rStore.ONE,
        YEAR_BLOCK_COUNT: rStore.YEAR_BLOCK_COUNT,
        baseRate: rStore.baseRate,
        optimalUtilRate: rStore.optimalUtilRate,
        slope1: rStore.slope1,
        slope2: rStore.slope2,
        isSet: rStore.isSet }));
    }
}
