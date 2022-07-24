// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "../interfaces/external/ICPMM.sol";

contract TestUniswapV2Pair is ERC20, ICPMM {
    address public token0;
    address public token1;
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    constructor(address _token0, address _token1) ERC20("", "") {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() external override view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast){
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function mint(address to) external override returns (uint liquidity) {
        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));
        blockTimestampLast = uint32(block.timestamp % 2**32);
        liquidity = 1000;
        _mint(to, liquidity);
    }

    function burn(address to) external override returns (uint amount0, uint amount1) {
        amount0 = reserve0 * 1000 / 10000;
        amount1 = reserve1 * 1000 / 10000;
        _burn(to, 10);
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override {

    }
}
