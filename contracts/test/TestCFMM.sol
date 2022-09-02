// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/external/ICPMM.sol";

contract TestCFMM is ICPMM {
    function getReserves()
        external
        view
        override
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {}

    function mint(address to) external override returns (uint256 liquidity) {}

    function burn(address to)
        external
        override
        returns (uint256 amount0, uint256 amount1)
    {}

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external override {}
}