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
        uint24 protocol;
        uint amount;
        uint[] amountsMin;
        address to;
        uint deadline;
    }

    struct BorrowLiquidityParams {
        address cfmm;
        uint24 protocol;
        uint256 liquidity;
        uint[] amountsMin;
        uint[] collateralAmounts;
        address to;
        uint deadline;
    }

    struct Position {
        // the nonce for permits
        uint96 nonce;
        address operator;
        address poolId;
        address[] tokens;
        uint256[] tokensHeld;
        uint256 liquidity;
        uint256 rateIndex;
        uint256 blockNum;
    }
}
