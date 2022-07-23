// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library UniswapV2Storage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.modules.uniswapv2");

    struct UniswapV2Store {
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

    function store() internal pure returns (UniswapV2Store storage store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            store.slot := position
        }
    }

    function init(address factory, address protocolFactory, uint24 protocol, bytes32 initCodeHash) internal {
        UniswapV2Store storage store = store();
        store.protocol = protocol;
        store.protocolFactory = protocolFactory;
        store.factory = factory;
        store.tradingFee1 = 1000;
        store.tradingFee2 = 997;
        store.BASE_RATE = 10**16;
        store.OPTIMAL_UTILIZATION_RATE = 8*(10**17);
        store.SLOPE1 = 10**18;
        store.SLOPE2 = 10**18;
        store.YEAR_BLOCK_COUNT = 2252571;
        store.initCodeHash = initCodeHash;
    }
}
