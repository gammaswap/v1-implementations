// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IProtocolModule {
    function getCFMM(address tokenA, address tokenB) external view returns(address cfmm);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) external returns (uint amountA, uint amountB, address cfmm);
    function mint(address from, address to) external returns(uint totalInvariant, uint invariant);
}
