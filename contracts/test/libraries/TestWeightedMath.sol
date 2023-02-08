// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.4;

import "../../libraries/weighted/WeightedMath.sol";

contract TestWeightedMath {
    constructor(){
    }

    function _calculateInvariant(uint256[] memory weights, uint256[] memory amounts) external virtual view returns(uint256 invariant) {
        invariant = WeightedMath._calculateInvariant(weights, amounts);
    }
}
