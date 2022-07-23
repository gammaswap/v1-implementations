pragma solidity ^0.8.0;

import "./LongGammaModule.sol";
import "../libraries/UniswapV2Storage.sol";
import "./UniswapV2BaseModule.sol";

contract UniswapV2LongGammaModule is UniswapV2BaseModule, LongGammaModule {

    constructor(address factory, address protocolFactory, uint24 protocol, bytes32 initCodeHash){
        UniswapV2Storage.init(factory, protocolFactory, protocol, initCodeHash);//bytes32(0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f));//UniswapV2
        //hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
        // bytes32(0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303));//SushiSwap
    }

    function convertLiquidityToAmounts(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity) internal view returns(uint256 amount0, uint256 amount1) {
        uint256 lastCFMMTotalSupply = store.lastCFMMTotalSupply;
        amount0 = liquidity * store.CFMM_RESERVES[0] / lastCFMMTotalSupply;
        amount1 = liquidity * store.CFMM_RESERVES[1] / lastCFMMTotalSupply;
    }

    function calcRepayAmounts(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override
        returns(uint256[] memory _tokensHeld, uint256[] memory amounts) { //, uint256 _lpTokensPaid, uint256 _liquidityPaid) {
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = convertLiquidityToAmounts(store, liquidity);
        require(tokensHeld[0] >= amounts[0] && tokensHeld[1] >= amounts[1], '< amounts');

        address cfmm = store.cfmm;
        TransferHelper.safeTransfer(store.tokens[0], cfmm, amounts[0]);
        TransferHelper.safeTransfer(store.tokens[1], cfmm, amounts[1]);

        //_lpTokensPaid = IUniswapV2PairMinimal(cfmm).mint(address(this));
        //_liquidityPaid = _lpTokensPaid * store.lastCFMMInvariant / store.lastCFMMTotalSupply;

        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] - amounts[0];
        _tokensHeld[1] = tokensHeld[1] - amounts[1];
    }

    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld){
        (uint256 amount0, uint256 amount1) = convertLiquidityToAmounts(store, liquidity);
        uint256 ONE = 10**18;
        uint256 inAmt0;
        uint256 inAmt1;
        uint256[] memory outAmts = new uint256[](2);//this gets subtracted from tokensHeld
        uint8 i;
        {
            uint256 reserve0 = store.CFMM_RESERVES[0];
            uint256 reserve1 = store.CFMM_RESERVES[1];
            uint256 currPx = reserve1 * ONE / reserve0;
            uint256 initPx = tokensHeld[1] * ONE / tokensHeld[0];
            if (currPx > initPx) {//we sell token0
                inAmt1 = liquidity * (Math.sqrt(currPx * ONE) - Math.sqrt(initPx * ONE));
            } else if(currPx < initPx) {//we sell token1
                inAmt1 = liquidity * (ONE - Math.sqrt((currPx * ONE / initPx) * ONE)) / Math.sqrt(currPx * ONE);
                (reserve0, reserve1, i) = (reserve1, reserve0, 1);
            }
            outAmts[i] = calcAmtOut(inAmt1, reserve0, reserve1);
        }
        if(i == 1) (inAmt0, inAmt1, amount0, amount1) = (inAmt1, inAmt0, amount1, amount0);
        require(outAmts[i] <= tokensHeld[i] - amount0, '> outAmt');
        address cfmm = store.cfmm;
        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] + inAmt0 - outAmts[0];
        _tokensHeld[1] = tokensHeld[1] + inAmt1 - outAmts[1];
        sendToken(store.tokens[0], cfmm, outAmts[0]);
        sendToken(store.tokens[1], cfmm, outAmts[1]);

        IUniswapV2PairMinimal(cfmm).swap(inAmt0,inAmt1, address(this), new bytes(0));
    }/**/

    function sendToken(address token, address to, uint256 amount) internal {
        if(amount > 0) TransferHelper.safeTransfer(token, to, amount);
    }

    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld) {
        (uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) = rebalancePosition(store.CFMM_RESERVES[0], store.CFMM_RESERVES[1], deltas[0], deltas[1]);
        _tokensHeld = new uint256[](2);

        _tokensHeld[0] = tokensHeld[0] + inAmt0 - outAmt0;
        _tokensHeld[1] = tokensHeld[1] + inAmt1 - outAmt1;

        address cfmm = store.cfmm;
        sendToken(store.tokens[0], cfmm, outAmt0);
        sendToken(store.tokens[1], cfmm, outAmt1);
        IUniswapV2PairMinimal(cfmm).swap(inAmt0,inAmt1,address(this), new bytes(0));/**/
    }

    function rebalancePosition(uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1) internal view returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        require((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0), 'bad delta');
        if(delta0 > 0 || delta1 > 0) {
            inAmt0 = uint256(delta1);//buy token1
            if(delta0 > 0) (inAmt0, reserve0, reserve1) = (uint256(delta0), reserve1, reserve0);//buy token0
            outAmt0 = calcAmtOut(inAmt0, reserve0, reserve1);
            if(inAmt0 != uint256(delta0)) (inAmt1, inAmt0, outAmt0, outAmt1) = (inAmt0, inAmt1, outAmt1, outAmt0);
        } else {
            outAmt0 = uint256(-delta0);//sell token0
            if(delta1 < 0) (outAmt0, reserve0, reserve1) = (uint256(-delta1), reserve1, reserve0);//sell token1
            inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1);
            if(outAmt0 != uint256(-delta0)) (inAmt0, inAmt1, outAmt0, outAmt1) = (inAmt1, inAmt0, outAmt1, outAmt0);
        }
    }

    // selling exactly amountOut
    function calcAmtIn(uint256 amountOut, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        UniswapV2Storage.UniswapV2Store storage store = UniswapV2Storage.store();
        uint256 amountOutWithFee = amountOut * store.tradingFee2;
        uint256 denominator = (reserveOut * store.tradingFee1) + amountOutWithFee;
        return amountOutWithFee * reserveIn / denominator;
    }

    // buying exactly amountIn
    function calcAmtOut(uint256 amountIn, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        UniswapV2Storage.UniswapV2Store storage store = UniswapV2Storage.store();
        uint256 denominator = (reserveIn - amountIn) * store.tradingFee2;
        return (reserveOut * amountIn * store.tradingFee1 / denominator) + 1;
    }
}
