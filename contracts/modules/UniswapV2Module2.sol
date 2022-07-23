// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseModule.sol";
import "../libraries/Math.sol";
import "../libraries/PoolAddress.sol";
import "../libraries/TransferHelper.sol";
import "../libraries/UniswapV2Storage.sol";
import "../interfaces/external/IUniswapV2PairMinimal.sol";

contract UniswapV2Module2 is BaseModule {

    constructor(address factory, address protocolFactory, uint24 protocol, bytes32 initCodeHash){
        UniswapV2Storage.init(factory, protocolFactory, protocol, initCodeHash);//bytes32(0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f));//UniswapV2
        //hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
        // bytes32(0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303));//SushiSwap
    }

    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }/**/

    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens, bytes32 key){
        require(isContract(_cfmm) == true, 'not contract');
        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        UniswapV2Storage.UniswapV2Store storage store = UniswapV2Storage.store();
        require(_cfmm == PoolAddress.computeAddress(store.protocolFactory,keccak256(abi.encodePacked(tokens[0], tokens[1])),store.initCodeHash), 'bad protocol');
        key = PoolAddress.getPoolKey(_cfmm, store.protocol);
    }

    function updateReserves(GammaPoolStorage.GammaPoolStore storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = IUniswapV2PairMinimal(store.cfmm).getReserves();
    }

    //Protocol specific functionality
    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        UniswapV2Storage.UniswapV2Store storage store = UniswapV2Storage.store();
        uint256 utilizationRate = (lpBorrowed * store.ONE) / (lpBalance + lpBorrowed);
        if(utilizationRate <= store.OPTIMAL_UTILIZATION_RATE) {
            uint256 variableRate = (utilizationRate * store.SLOPE1) / store.OPTIMAL_UTILIZATION_RATE;
            return (store.BASE_RATE + variableRate);
        } else {
            uint256 utilizationRateDiff = utilizationRate - store.OPTIMAL_UTILIZATION_RATE;
            uint256 variableRate = (utilizationRateDiff * store.SLOPE2) / (store.ONE - store.OPTIMAL_UTILIZATION_RATE);
            return(store.BASE_RATE + store.SLOPE1 + variableRate);
        }
    }

    //TODO:  (Needs to avoid GPL)
    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, '> amount');
        require(reserveA > 0 && reserveB > 0, '0 reserve');
        amountB = (amountA * reserveB) / reserveA;
    }

    //TODO: becomes internal (Needs to avoid GPL)
    function calcAmounts(
        GammaPoolStorage.GammaPoolStore storage store,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin
    ) internal virtual override returns (uint256[] memory amounts, address payee) {
        amounts = new uint256[](2);
        payee = store.cfmm;
        (uint256 reserveA, uint256 reserveB) = (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1]);
        if (reserveA == 0 && reserveB == 0) {
            //(amounts[0], amounts[1]) = (amountsDesired[0], amountsDesired[1]);
            return(amountsDesired, payee);
        } //else {
            uint amountBOptimal = quote(amountsDesired[0], reserveA, reserveB);
            if (amountBOptimal <= amountsDesired[1]) {
                require(amountBOptimal >= amountsMin[1], '> amountB');
                (amounts[0], amounts[1]) = (amountsDesired[0], amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountsDesired[1], reserveB, reserveA);
                assert(amountAOptimal <= amountsDesired[0]);
                require(amountAOptimal >= amountsMin[0], '> amountA');
                (amounts[0], amounts[1]) = (amountAOptimal, amountsDesired[1]);
            }
        return(amounts, payee);
        //}
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override {
        IUniswapV2PairMinimal(cfmm).mint(to);
    }

    //TODO: Can be delegated
    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint[] memory amounts) {
        TransferHelper.safeTransfer(cfmm, cfmm, amount);
        amounts = new uint[](2);
        (amounts[0], amounts[1]) = IUniswapV2PairMinimal(cfmm).burn(to);/**/
    }

    function calcInvariant(address cfmm, uint[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }

    function convertLiquidityToAmounts(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity) internal view returns(uint256 amount0, uint256 amount1) {
        uint256 lastCFMMTotalSupply = store.lastCFMMTotalSupply;
        amount0 = liquidity * store.CFMM_RESERVES[0] / lastCFMMTotalSupply;
        amount1 = liquidity * store.CFMM_RESERVES[1] / lastCFMMTotalSupply;
    }

    function repayLiquidity(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld, uint256[] memory amounts, uint256 _lpTokensPaid, uint256 _liquidityPaid) {
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = convertLiquidityToAmounts(store, liquidity);
        require(tokensHeld[0] >= amounts[0] && tokensHeld[1] >= amounts[1], '< amounts');

        address cfmm = store.cfmm;
        TransferHelper.safeTransfer(store.tokens[0], cfmm, amounts[0]);
        TransferHelper.safeTransfer(store.tokens[1], cfmm, amounts[1]);

        _lpTokensPaid = IUniswapV2PairMinimal(cfmm).mint(address(this));
        _liquidityPaid = _lpTokensPaid * store.lastCFMMInvariant / store.lastCFMMTotalSupply;

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
            outAmts[i] = getAmtOut(inAmt1, reserve0, reserve1);
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
            outAmt0 = getAmtOut(inAmt0, reserve0, reserve1);
            if(inAmt0 != uint256(delta0)) (inAmt1, inAmt0, outAmt0, outAmt1) = (inAmt0, inAmt1, outAmt1, outAmt0);
        } else {
            outAmt0 = uint256(-delta0);//sell token0
            if(delta1 < 0) (outAmt0, reserve0, reserve1) = (uint256(-delta1), reserve1, reserve0);//sell token1
            inAmt1 = getAmtIn(outAmt0, reserve0, reserve1);
            if(outAmt0 != uint256(-delta0)) (inAmt0, inAmt1, outAmt0, outAmt1) = (inAmt1, inAmt0, outAmt1, outAmt0);
        }
    }

    //TODO: Needs to avoid GPL
    // selling exactly amountOut
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmtIn(uint amountOut, uint reserveOut, uint reserveIn) internal view returns (uint256) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint256 amountOutWithFee = amountOut * UniswapV2Storage.store().tradingFee2;
        uint256 denominator = (reserveOut * UniswapV2Storage.store().tradingFee1) + amountOutWithFee;
        return amountOutWithFee * reserveIn / denominator;
    }

    //TODO: Needs to avoid GPL
    // buying exactly amountIn
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmtOut(uint amountIn, uint reserveOut, uint reserveIn) internal view returns (uint256) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint256 denominator = (reserveIn - amountIn) * UniswapV2Storage.store().tradingFee2;
        return (reserveOut * amountIn * UniswapV2Storage.store().tradingFee1 / denominator) + 1;
    }
}
