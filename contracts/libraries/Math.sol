// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "hardhat/console.sol";

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

    function powDown(uint256 x, uint256 y) internal view returns (uint256) {
        console.log('Attempting to powDown for x: ', x, ' and y: ', y);
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        uint ONE = 1e18;
        uint TWO = 2e18;
        uint FOUR = 4e18;
        if (y == ONE) {
            return x;
        } else if (y == TWO) {
            return x * x;
        } else if (y == FOUR) {
            uint256 square = x * x;
            return square * square;
        } else {
            uint256 raw = LogExpMath.pow(x, y);
            console.log('raw: ', raw);
            uint256 maxError = raw * 10000 + 1;

            if (raw < maxError) {
                return 0;
            } else {
                
                return raw - maxError;
            }
        }
    }

    function _calculateInvariant(uint256[] memory normalizedWeights, uint256[] memory balances) internal view returns (uint256 invariant){
        // invariant = 1e18;
        // for (uint256 i = 0; i < normalizedWeights.length; i++) {
        //     invariant = invariant * powDown(balances[i], normalizedWeights[i]);
        // }

        // TODO: Need some help calculating this for general powers in Solidity
        if ((normalizedWeights[0] == 5e17) && (normalizedWeights[1] == 5e17)) {
            invariant = Math.sqrt(uint256(balances[0]) * balances[1]);
            }
        else {
            invariant = 1e18;
        }
        _require(invariant > 0, Errors.ZERO_INVARIANT);
    }

    function convertToUint256Array(uint128[] memory amounts) internal pure returns (uint256[] memory newAmounts) {
        newAmounts = new uint256[](amounts.length);
        for (uint i = 0; i < amounts.length; i++) {
            newAmounts[i] = uint256(amounts[i]);
    }
}

}