// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library CPMMStrategyStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.strategies.cpmm");

    struct Store {
        //cfmm validation
        address factory;//protocol factory
        bytes32 initCodeHash;

        //trading fees
        uint16 tradingFee1;// = 1000;
        uint16 tradingFee2;// = 997;
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init(address factory, bytes32 initCodeHash, uint16 tradingFee1, uint16 tradingFee2) internal {
        Store storage _store = store();
        _store.factory = factory;
        _store.initCodeHash = initCodeHash;
        _store.tradingFee1 = tradingFee1;
        _store.tradingFee2 = tradingFee2;
    }
}
