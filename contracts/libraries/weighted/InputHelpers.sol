// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/helpers/BalancerErrors.sol";

library InputHelpers {
    function ensureInputLengthMatch(uint256 a, uint256 b) internal pure {
        _require(a == b, Errors.INPUT_LENGTH_MISMATCH);
    }

    function ensureInputLengthMatch(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure {
        _require(a == b && b == c, Errors.INPUT_LENGTH_MISMATCH);
    }

    function ensureArrayIsSorted(IERC20[] memory array) internal pure {
        address[] memory addressArray;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            addressArray := array
        }
        ensureArrayIsSorted(addressArray);
    }

    function ensureArrayIsSorted(address[] memory array) internal pure {
        if (array.length < 2) {
            return;
        }

        address previous = array[0];
        for (uint256 i = 1; i < array.length;) {
            address current = array[i];
            _require(previous < current, Errors.UNSORTED_ARRAY);
            previous = current;
            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Upscales a value by a given scaling factor.
     */
    function upscale(uint256 value, uint256 scalingFactor) internal view returns (uint256) {
        return value * scalingFactor;
    }

    /**
     * @dev Downscales a value by a given scaling factor.
     */
    function downscale(uint256 value, uint256 scalingFactor) internal pure returns (uint256) {
        return value / scalingFactor;
    }

    /**
     * @dev Upscales an array of values by a given scaling factor.
     */
    function upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view returns (uint256[] memory){
        uint256 length = amounts.length;
        ensureInputLengthMatch(length, scalingFactors.length);

        for (uint256 i = 0; i < length;) {
            amounts[i] = upscale(amounts[i], scalingFactors[i]);
            unchecked {
                i++;
            }
        }

        return amounts;
    } 

    /**
     * @dev Downscales an array of values by a given scaling factor.
     */
    function downscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal pure returns (uint256[] memory){
        uint256 length = amounts.length;
        ensureInputLengthMatch(length, scalingFactors.length);

        for (uint256 i = 0; i < length;) {
            amounts[i] = downscale(amounts[i], scalingFactors[i]);
            unchecked {
                i++;
            }
        }

        return amounts;
    }

    /**
     * @dev Returns the scaling factor for the given token.
     * @notice Tokens with more than 18 decimals are not supported.
     * @notice Implementation is different from Balancer's one, as we don't scale the return value up by 1e18.
     */
    function getScalingFactor(uint8 decimals) internal pure returns (uint256) {
        // As in Balancer documentation, tokens with more than 18 decimals are not supported.
        unchecked{
            uint256 decimalsDifference = 18 - decimals;
            return 10 ** decimalsDifference;
        }
    }

    /**
     * @dev Returns an array of scaling factors for the given tokens.
     */
    //function getScalingFactors(address[] memory tokens) internal view returns (uint256[] memory) {
    function getScalingFactors(uint8[] memory decimals) internal view returns (uint256[] memory) {
        uint256[] memory scalingFactors = new uint256[](decimals.length);
        for (uint256 i = 0; i < decimals.length;) {
            scalingFactors[i] = getScalingFactor(decimals[i]);
            unchecked {
                i++;
            }
        }
        return scalingFactors;
    }

    function castToUint256Array(uint128[] memory values) internal pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](values.length);
        for (uint256 i = 0; i < values.length;) {
            result[i] = uint256(values[i]);
            unchecked {
                i++;
            }
        }
        return result;
    }
}
