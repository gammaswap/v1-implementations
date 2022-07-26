// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./ITransfers.sol";

interface IPositionManager  is ITransfers {
    struct AddLPLiquidityParams {
        address cfmm;
        uint24 protocol;
        uint256 lpTokens;
        address to;
        uint256 deadline;
    }

    struct AddLiquidityParams {
        address cfmm;
        uint256[] amountsDesired;
        uint256[] amountsMin;
        address to;
        uint24 protocol;
        uint256 deadline;
    }

    struct RemoveLiquidityParams {
        address cfmm;
        uint24 protocol;
        uint256 amount;
        uint256[] amountsMin;
        address to;
        uint256 deadline;
    }

    struct BorrowLiquidityParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        uint256 lpTokens;
        address to;
        uint256 deadline;
    }

    struct RepayLiquidityParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        uint256 liquidity;
        address to;
        uint256 deadline;
    }

    struct AddRemoveCollateralParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        uint256[] amounts;
        address to;
        uint256 deadline;
    }

    struct RebalanceCollateralParams {
        address cfmm;
        uint24 protocol;
        uint256 tokenId;
        int256[] deltas;
        uint256 liquidity;
        address to;
        uint deadline;
    }

    function factory() external view returns (address);

    //Short Gamma
    function addLPLiquidity(AddLPLiquidityParams calldata params) external returns(uint256 liquidity);
    function addLiquidity(AddLiquidityParams calldata params) external returns (uint256[] memory amounts, uint256 liquidity);
    function removeLiquidity(RemoveLiquidityParams calldata params) external returns (uint256[] memory amounts);

    //Long Gamma
    function createLoan(address cfmm, uint24 protocol, address to, uint256 deadline) external returns(uint256 tokenId);
    function loan(address cfmm, uint24 protocol, uint256 tokenId) external view returns (uint256 id, address poolId,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum);
    function borrowLiquidity(BorrowLiquidityParams calldata params) external returns (uint256[] memory amounts);
    function repayLiquidity(RepayLiquidityParams calldata params) external returns (uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts);
    function increaseCollateral(AddRemoveCollateralParams calldata params) external returns(uint256[] memory tokensHeld);
    function decreaseCollateral(AddRemoveCollateralParams calldata params) external returns(uint256[] memory tokensHeld);
    function rebalanceCollateral(RebalanceCollateralParams calldata params) external returns(uint256[] memory tokensHeld);
    function rebalanceCollateralWithLiquidity(RebalanceCollateralParams calldata params) external returns(uint256[] memory tokensHeld);
}
