// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../protocols/CPMMProtocol.sol";

contract TestCPMMProtocol is CPMMProtocol {
    constructor(address gsFactory, uint24 _protocol, bytes memory pData, address longStrategy, address shortStrategy)
        CPMMProtocol(gsFactory, _protocol, pData, longStrategy, shortStrategy) {
    }

    function testStrategyParams() public virtual view returns(bytes memory) {
        return strategyParams();
    }

    function testRateParams() public virtual view returns(bytes memory) {
        return rateParams();
    }

    function testInitializeStrategyParams(bytes calldata sData) public virtual {
        initializeStrategyParams(sData);
    }

    function testInitializeRateParams(bytes calldata rData) public virtual {
        initializeRateParams(rData);
    }
}
