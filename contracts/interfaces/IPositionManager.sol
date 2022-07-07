// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IPeripheryPayments.sol";
import "./IPeripheryImmutableState.sol";

interface IPositionManager  is IPeripheryPayments, IPeripheryImmutableState {

    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint amountADesired;
        uint amountBDesired;
        uint amountAMin;
        uint amountBMin;
        address to;
        uint24 protocol;
        uint deadline;
    }/**/

}
