// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/PoolAddress.sol";
import "../libraries/GammaSwapLibrary.sol";

contract TestPoolAddress {
    function getInitCodeHash() external pure returns(bytes32 hash) {
        hash = PoolAddress.POOL_INIT_CODE_HASH;
    }

    function calcAddress(address factory, bytes32 key) external pure returns(address pool){
        pool = PoolAddress.calcAddress(factory, key);
    }

    function getPoolAddress(address factory, address tokenA, address tokenB, uint24 protocol) external pure returns(address pool){
        /*(address token0, address token1) = GammaSwapLibrary.sortTokens(tokenA, tokenB);
        PoolAddress.PoolKey memory key = PoolAddress.getPoolKey(token0, token1, protocol);
        pool = PoolAddress.calcAddress(factory, key);/**/
    }
}
