// SPDX-License-Identifier: GPL-2.0-or-later
//pragma solidity >=0.6.2;
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import './Math.sol';

library GammaswapLibrary {

    function rootNumber(uint256 num) internal view returns(uint256 root) {
        root = Math.sqrt(num * (10**18));
    }

    function min(uint num0, uint num1) internal view returns(uint res) {
        res = Math.min(num0, num1);
    }

    function min2(uint256 num0, uint256 num1) internal view returns(uint256 res) {
        res = Math.min2(num0, num1);
    }

    function convertLiquidityToAmounts(uint256 liquidity, uint256 px) internal view returns(uint256 amount0, uint256 amount1) {
        uint256 pxRoot = rootNumber(px);
        uint256 _one = (10**18);
        amount0 = (liquidity * _one) / pxRoot;
        amount1 = (liquidity * pxRoot) / _one;
    }

    function convertPoolLiquidityToAmounts(address uniPair, uint256 liquidity) internal view returns(uint256 amount0, uint256 amount1) {
        uint256 px = getPairPx(uniPair);
        (amount0, amount1) = convertLiquidityToAmounts(liquidity, px);
    }

    //Uniswap
    function getPairPx(address uniPair) internal view returns(uint256 px) {
        //(uint256 reserve0, uint256 reserve1) = getCPMReserves(uniPair);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(uniPair).getReserves();
        px = (reserve1 * (10**18)) / reserve0;
    }

    function getBorrowedReserves(address uniPair, uint256 _uniReserve0, uint256 _uniReserve1, uint256 totalUniLiquidity, uint256 borrowedInvariant) internal view returns(uint256 _reserve0, uint256 _reserve1) {
        //borrowedInvariant
        uint256 uniTotalSupply = IERC20(uniPair).totalSupply();
        _reserve0 = (_uniReserve0 * totalUniLiquidity) / uniTotalSupply;
        _reserve1 = (_uniReserve1 * totalUniLiquidity) / uniTotalSupply;
        if(borrowedInvariant > 0) {
            uint256 resRoot1 = rootNumber(_uniReserve1);
            uint256 resRoot0 = rootNumber(_uniReserve0);
            uint256 vegaReserve1 = (borrowedInvariant * resRoot1) / resRoot0;
            uint256 vegaReserve0 = (borrowedInvariant * resRoot0) / resRoot1;
            _reserve0 = _reserve0 + vegaReserve0;
            _reserve1 = _reserve1 + vegaReserve1;
        }
    }

    function getTokenBalances(address _token0, address _token1, address _of) internal view returns(uint256 balance0, uint256 balance1) {
        balance0 = IERC20(_token0).balanceOf(_of);
        balance1 = IERC20(_token1).balanceOf(_of);
    }

    function convertAmountsToLiquidity(uint256 amount0, uint256 amount1) internal view returns(uint256 liquidity) {
        liquidity = Math.sqrt(amount0 * amount1);
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'GammaswapLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GammaswapLibrary: ZERO_ADDRESS');
    }

    // fetches and sorts the reserves for a pair
    function getUniReserves(address uniPair, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(uniPair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'GammaswapLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'GammaswapV1Library: INSUFFICIENT_LIQUIDITY');
        amountB = (amountA * reserveB) / reserveA;
    }
}