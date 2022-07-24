// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ILongStrategy {
    function increaseCollateral(uint256 tokenId) external returns(uint256[] memory);
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint256[] memory tokensHeld);
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts);
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint256[] memory tokensHeld);
    function rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256[] memory tokensHeld);
}