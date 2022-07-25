// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library DoubleLinearRateStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.rates.doublelinear");

    struct Store {
        uint256 ONE;// = 10**18;
        uint256 YEAR_BLOCK_COUNT;// = 2252571;
        //interest rate models
        uint256 baseRate;// = 10**16;
        uint256 optimalUtilRate;// = 8*(10**17);
        uint256 slope1;// = 10**18;
        uint256 slope2;// = 10**18;
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init(uint256 baseRate, uint256 optimalUtilRate, uint256 slope1, uint256 slope2) internal {
        Store storage _store = store();
        _store.ONE = 10**18;
        _store.YEAR_BLOCK_COUNT = 2252571;
        _store.baseRate = baseRate;
        _store.optimalUtilRate = optimalUtilRate;
        _store.slope1 = slope1;
        _store.slope1 = slope2;
    }
}
