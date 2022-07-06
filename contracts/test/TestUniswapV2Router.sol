pragma solidity ^0.8.0;

import "../routers/UniswapV2Router.sol";

contract TestUniswapV2Router is UniswapV2Router{

    constructor(address _factory) UniswapV2Router(_factory) {

    }

    function testPairFor(address tokenA, address tokenB) external view returns(address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = pairFor(factory, token0, token1);
    }
}
