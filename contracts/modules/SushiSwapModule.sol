// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./UniswapV2Module.sol";

contract SushiSwapModule is UniswapV2Module {

    constructor(address _factory, address _protocolFactory) UniswapV2Module(_factory, _protocolFactory) {
        protocol = 2;
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal override view returns (address pair) {
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                protocolFactory,
                keccak256(abi.encodePacked(tokenA, tokenB)),
                hex'e18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303' // init code hash
            )))));
    }
}
