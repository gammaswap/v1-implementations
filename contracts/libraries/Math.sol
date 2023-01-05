// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

// A library for performing various math operations

import "./LogExpMath.sol";

library Math {
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x > y ? x : y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding down. The result is guaranteed to not be above
     * the true value (that is, the error function expected - actual is always positive).
     */
    function power(uint256 x, uint256 y) internal pure returns (uint256) {
        uint ONE = 1e18;
        uint TWO = 2e18;
        uint FOUR = 4e18;
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        if (y == ONE) {
            return x;
        } else if (y == TWO) {
            return x * x / ONE;
        } else if (y == FOUR) {
            uint256 square = x * x / ONE;
            return square * square / ONE;
        } else {
            uint256 raw = LogExpMath.pow(x, y);
            uint256 maxError = raw * 10000 + 1;

            if (raw < maxError) {
                return 0;
            } else {
                return raw - maxError;
            }
        }
    }
}