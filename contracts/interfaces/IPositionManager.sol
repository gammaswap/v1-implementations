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
        uint256 tokenId;
        uint256 liquidity;
        uint[] amountsMin;
        uint[] collateralAmounts;
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

    struct AddRemoveCollateralParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        uint[] amounts;
        address to;
        uint deadline;
    }

    struct RebalanceCollateralParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        uint[] posDeltas;
        uint[] negDeltas;
        uint256 liquidity;
        address to;
        uint deadline;
    }

    function createLoan(address cfmm, uint24 protocol, address to) external returns(uint256 tokenId);
    function addLiquidity(AddLiquidityParams calldata params) external returns (uint[] memory amounts, uint liquidity);
    function removeLiquidity(RemoveLiquidityParams calldata params) external returns (uint[] memory amounts);
    function borrowLiquidity(BorrowLiquidityParams calldata params) external returns (uint[] memory amounts);
    //function borrowMoreLiquidity(uint256 tokenId, BorrowLiquidityParams calldata params) external returns (uint[] memory amounts);
    function repayLiquidity(RepayLiquidityParams calldata params) external returns (uint liquidityPaid, uint lpTokensPaid, uint[] memory amounts);
    function increaseCollateral(AddRemoveCollateralParams calldata params) external returns(uint[] memory tokensHeld);
    function decreaseCollateral(AddRemoveCollateralParams calldata params) external returns(uint[] memory tokensHeld);
    function rebalanceCollateral(RebalanceCollateralParams calldata params) external returns(uint[] memory tokensHeld);
    function rebalanceCollateralWithLiquidity(RebalanceCollateralParams calldata params) external returns(uint[] memory tokensHeld);
}
