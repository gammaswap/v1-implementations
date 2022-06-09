// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import './Math.sol';
import "../interfaces/IDepositPool.sol";
import "../interfaces/IPositionManager.sol";

library GammaswapPosLibrary {

    function min(uint num0, uint num1) internal view returns(uint res) {
        res = Math.min(num0, num1);
    }

    //Uniswap
    function getPairPx(address uniPair) internal view returns(uint256 px) {
        //(uint256 reserve0, uint256 reserve1) = getCPMReserves(uniPair);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(uniPair).getReserves();
        px = (reserve1 * (10**18)) / reserve0;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'GammaswapPosLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GammaswapPosLibrary: ZERO_ADDRESS');
    }

    function rootNumber(uint256 num) internal view returns(uint256 root) {
        root = Math.sqrt(num * (10**18));
    }

    function convertLiquidityToOneAmount(uint256 liquidity, uint256 reserve0, uint256 reserve1) internal view returns(uint256 amount) {
        amount = ((liquidity * rootNumber(reserve1)) / rootNumber(reserve0)) * 2;//TODO: This calculation is less accurate because  of the root
    }

    function convertLiquidityToOneAmount(uint256 liquidity, uint256 px) internal view returns(uint256 amount) {
        amount = ((liquidity * rootNumber(px)) / (10**18)) * 2;//TODO: Make sure this can't be hacked
    }

    function getPositionBalances(address uniPair, uint256 liquidity, uint256 tokensHeld0, uint256 tokensHeld1) //, uint256 uniPairHeld)
        internal view returns(uint256 owedBalance, uint256 heldBalance) {
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(uniPair).getReserves();

        uint256 px = (reserve1 * (10**18)) / reserve0;
        owedBalance = convertLiquidityToOneAmount(liquidity, px);
        heldBalance = tokensHeld1 + ((tokensHeld0 * reserve1) / reserve0);
        /*if(uniPairHeld > 0) {
            uint256 uniTotalSupply = IERC20(uniPair).totalSupply();
            uint256 uniPairHeldBalance = ((uniPairHeld * reserve1) * 2) / uniTotalSupply;
            heldBalance = heldBalance + uniPairHeldBalance;
        }/**/
    }

    function convertAmountsToLiquidity(uint256 amount0, uint256 amount1) internal view returns(uint256 liquidity) {
        liquidity = Math.sqrt(amount0 * amount1);
    }

    function getTokenBalances(address _token0, address _token1, address _of) internal view returns(uint256 balance0, uint256 balance1) {
        balance0 = IERC20(_token0).balanceOf(_of);
        balance1 = IERC20(_token1).balanceOf(_of);
    }

    function getLiquidityRate(address poolId, uint256 rateIndex) internal view returns(uint256 _accFeeIndex, uint256 _liquidityRate) {
        (_accFeeIndex, , , ) = IDepositPool(poolId).getLastFeeIndex();
        _liquidityRate = (_accFeeIndex * (10**18)) / rateIndex;
    }

    function getPositionLiquidity(IPositionManager.Position storage position) internal view returns(uint256 rateIndex, uint256 liquidity) {
        uint256 rate;
        (rateIndex, rate) = getLiquidityRate(position.poolId, position.rateIndex);
        liquidity = (position.liquidity * rate) / (10**18);
    }

    /*Check collateral:
            -If call or put, it must be at maxLoss % of init + 20% to open - maxLoss % + 10% to hold
            -If straddle, it must be at 20% to open - 10% to hold We won't include the maxLoss. It is not necessary. It is only necessary to have 25% the value of the position
        */
    function checkCollateral(IPositionManager.Position storage position, uint16 limit) internal {
        (, uint256 liquidity) = getPositionLiquidity(position);//We store the interest charged as added liquidity. To do that we have to square the cumRate
        (uint256 owedBalance, uint256 heldBalance) = getPositionBalances(position.uniPair, liquidity, position.tokensHeld0, position.tokensHeld1);//, position.uniPairHeld);
        require((heldBalance * limit) / 1000 >= owedBalance, 'GammaswapPosLibrary: INSUFFICIENT_COLLATERAL_DEPOSITED');
    }


    /*function swapPositionExactTokensForTokens(IPositionManager.Position storage position, IPositionManager.RebalanceParams calldata params) internal {

        //uint256 MAX_SLIPPAGE = 10**17;//10%
        //uint256 ONE = 10**18;//1
        uint256 origAmt;
        //uint256 px = getPairPx(position.uniPair);
        //uint256 maxSlippage = 10**17;
        if(params.side) {
            origAmt = IERC20(position.token0).balanceOf(address(this));
            position.tokensHeld1 = position.tokensHeld1 - params.amount;
            uint256 amountOutMin = (params.amount * (9 * (10**17))) / getPairPx(position.uniPair);
            swapExactTokensForTokens(position.token1, position.token0, amountOutMin, params.amount, address(this));
        } else {
            origAmt = IERC20(position.token1).balanceOf(address(this));
            position.tokensHeld0 = position.tokensHeld0 - params.amount;
            uint noSlipAmt = (params.amount * getPairPx(position.uniPair)) / (10**18);
            uint256 amountOutMin = (noSlipAmt * (9 * (10**17))) / (10**18);
            swapExactTokensForTokens(position.token0, position.token1, amountOutMin, params.amount, address(this));
        }

        if(params.side) {
            position.tokensHeld0 = IERC20(position.token0).balanceOf(address(this)) - origAmt + position.tokensHeld0;
        } else {
            position.tokensHeld1 = IERC20(position.token1).balanceOf(address(this)) - origAmt + position.tokensHeld1;
        }

        checkCollateral(position, 850);

        //(_tokenBalances[position.token0], _tokenBalances[position.token1]) = GammaswapPosLibrary.getTokenBalances(position.token0, position.token1, address(this));
    }/**/
    /*function GammaswapPosLibrary(){

    }/**/
}
