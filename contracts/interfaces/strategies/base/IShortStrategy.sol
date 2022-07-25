// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IShortStrategy {
    function mint(address to) external returns(uint256 liquidity);
    function burn(address to) external returns (uint256[] memory amounts);
    function addLiquidity(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory amounts, uint256 liquidity);
}
