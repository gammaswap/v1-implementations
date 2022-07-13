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

    struct ChangeCollateralParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        uint[] amounts;
        address to;
        uint deadline;
    }

    struct RepayLiquidityParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        uint256 liquidity;
        uint[] amounts;
        address to;
        uint deadline;
    }

}
