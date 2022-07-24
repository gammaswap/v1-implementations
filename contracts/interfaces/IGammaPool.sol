// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IGammaPool {
    //Short Gamma
    function _mint(address to) external returns(uint256 liquidity);
    function _burn(address to) external returns (uint256[] memory amounts);
    function _addLiquidity(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory amounts);

    //Long Gamma
    function _increaseCollateral(uint256 tokenId) external returns(uint256[] memory tokensHeld);
    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint256[] memory tokensHeld);
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);
    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts);
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint256[] memory tokensHeld);
    function _rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256[] memory tokensHeld);
}
