// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IPeripheryPayments.sol";
import "./IPeripheryImmutableState.sol";

interface IPositionManager  is IPeripheryPayments, IPeripheryImmutableState {

    struct AddLiquidityParams {
        address cfmm;
        uint[] amountsDesired;
        uint[] amountsMin;
        address to;
        uint24 protocol;
        uint deadline;
    }

    struct RemoveLiquidityParams {
        address cfmm;
        uint amount;
        uint[] amountsMin;
        address to;
        uint24 protocol;
        uint deadline;
    }

}
