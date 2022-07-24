// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library CPMMStrategyStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.strategies.cpmm");

    struct Store {
        uint256 ONE;// = 10**18;
        uint24 protocol;
        address factory;
        address protocolFactory;//protocol factory

        uint16 tradingFee1;// = 1000;
        uint16 tradingFee2;// = 997;

        uint256 BASE_RATE;// = 10**16;
        uint256 OPTIMAL_UTILIZATION_RATE;// = 8*(10**17);
        uint256 SLOPE1;// = 10**18;
        uint256 SLOPE2;// = 10**18;

        uint256 YEAR_BLOCK_COUNT;// = 2252571;

        bytes32 initCodeHash;
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init(address factory, address protocolFactory, uint24 protocol, bytes32 initCodeHash) internal {
        Store storage _store = store();
        _store.protocol = protocol;
        _store.protocolFactory = protocolFactory;
        _store.factory = factory;
        _store.tradingFee1 = 1000;
        _store.tradingFee2 = 997;
        _store.BASE_RATE = 10**16;
        _store.OPTIMAL_UTILIZATION_RATE = 8*(10**17);
        _store.SLOPE1 = 10**18;
        _store.SLOPE2 = 10**18;
        _store.YEAR_BLOCK_COUNT = 2252571;
        _store.initCodeHash = initCodeHash;
    }
}
