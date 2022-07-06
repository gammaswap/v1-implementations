// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library GammaSwapLibrary {

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'GammaswapLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GammaswapLibrary: ZERO_ADDRESS');
    }
}
