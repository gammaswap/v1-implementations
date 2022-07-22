// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseModule.sol";
import "../libraries/Math.sol";
import "../libraries/PoolAddress.sol";
import "../libraries/TransferHelper.sol";
import "../libraries/UniswapV2Storage.sol";
import "../interfaces/external/IUniswapV2PairMinimal.sol";

contract UniswapV2Module2 is BaseModule {

    constructor(address factory, address protocolFactory, uint24 protocol){
        UniswapV2Storage.init(factory, protocolFactory, protocol);
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
        require(_cfmm == pairFor(tokens[0], tokens[1]), 'bad protocol');
        key = PoolAddress.getPoolKey(_cfmm, UniswapV2Storage.store().protocol);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal virtual view returns (address pair) {
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                UniswapV2Storage.store().protocolFactory,
                keccak256(abi.encodePacked(tokenA, tokenB)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }

    function calcCFMMTotalInvariant(address cfmm) internal virtual override view returns(uint256) {
        (uint256 reserveA, uint256 reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();//TODO: This might need a check to make sure that (reserveA * reserveB) do not overflow
        return Math.sqrt(reserveA * reserveB);
    }

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

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, '> amount');
        require(reserveA > 0 && reserveB > 0, '0 reserve');
        amountB = (amountA * reserveB) / reserveA;
    }

    //TODO: becomes internal
    function calcAmounts(
        address cfmm,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin
    ) internal virtual override returns (uint[] memory amounts, address payee) {
        payee = cfmm;
        amounts = new uint[](2);
        (uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();
        if (reserveA == 0 && reserveB == 0) {
            (amounts[0], amounts[1]) = (amountsDesired[0], amountsDesired[1]);
        } else {
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
        }
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

    //See if can use separate functions one that returns amoutns only and one reserves too, but without using arrays to save memory in the filesize
    function convertLiquidityToAmounts(address cfmm, uint256 liquidity) internal view returns(uint256[] memory amounts, uint256 reserve0, uint256 reserve1) {
        /*(reserve0, reserve1,) = IUniswapV2PairMinimal(cfmm).getReserves();
        amounts = new uint256[](2);
        uint256 cfmmInvariant = Math.sqrt(reserve0 * reserve1);
        amounts[0] = liquidity * reserve0 / cfmmInvariant;
        amounts[1] = liquidity * reserve1 / cfmmInvariant;/**/
    }

    function repayLiquidity(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld, uint256[] memory amounts, uint256 _lpTokensPaid, uint256 _liquidityPaid) {
        (amounts,,) = convertLiquidityToAmounts(store.cfmm, liquidity);//TODO: Do this calculation without calling uniswap x=L/sqrt(p), y=L*sqrt(p)
        require(tokensHeld[0] >= amounts[0] && tokensHeld[1] >= amounts[1], '< amounts');

        TransferHelper.safeTransfer(store.tokens[0], store.cfmm, amounts[0]);
        TransferHelper.safeTransfer(store.tokens[1], store.cfmm, amounts[1]);

        _lpTokensPaid = IUniswapV2PairMinimal(store.cfmm).mint(address(this));
        //_liquidityPaid = _lpTokensPaid * calcCFMMTotalInvariant(store.cfmm) / GammaSwapLibrary.totalSupply(store.cfmm);
        _liquidityPaid = _lpTokensPaid * store.lastCFMMInvariant / store.lastCFMMTotalSupply;

        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] - amounts[0];
        _tokensHeld[1] = tokensHeld[1] - amounts[1];
    }

    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld){
        uint256 reserve0;
        uint256 reserve1;
        uint256[] memory amounts;
        (amounts, reserve0, reserve1) = convertLiquidityToAmounts(store.cfmm, liquidity);//TODO: Do this calculation without calling uniswap x=L/sqrt(p), y=L*sqrt(p)

        uint256 ONE = 10**18;
        uint256 inAmt0;
        uint256 inAmt1;
        uint8 i;
        {
            uint256 currPx = reserve1 * ONE / reserve0;
            uint256 initPx = tokensHeld[1] * ONE / tokensHeld[0];
            if (currPx > initPx) {//we sell token0
                inAmt0 = liquidity * (Math.sqrt(currPx * ONE) - Math.sqrt(initPx * ONE));
            } else if(currPx < initPx) {//we sell token1
                inAmt0 = liquidity * (ONE - Math.sqrt((currPx * ONE / initPx) * ONE)) / Math.sqrt(currPx * ONE);
                (reserve0, reserve1, i) = (reserve1, reserve0, 1);
            }
        }
        uint256[] memory outAmts = new uint256[](2);//this gets subtracted from tokensHeld
        _tokensHeld = new uint256[](2);
        outAmts[i] = getAmountOut(inAmt0, reserve0, reserve1);
        if(i == 0) (inAmt0, inAmt1) = (inAmt1, inAmt0);
        require(outAmts[i] <= tokensHeld[i] - amounts[i], '> outAmt');
        _tokensHeld[0] = tokensHeld[0] + inAmt0 - outAmts[0];
        _tokensHeld[1] = tokensHeld[1] + inAmt1 - outAmts[1];
        sendToken(store.tokens[0], store.cfmm, outAmts[0]);
        sendToken(store.tokens[1], store.cfmm, outAmts[1]);
        IUniswapV2PairMinimal(store.cfmm).swap(inAmt0,inAmt1, address(this), new bytes(0));
    }/**/

    function sendToken(address token, address to, uint256 amount) internal {
        if(amount > 0) TransferHelper.safeTransfer(token, to, amount);
    }

    //function rebalancePosition(address cfmm, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld) {
    function rebalancePosition(GammaPoolStorage.GammaPoolStore storage store, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld) {

        //address gammaPool = getGammaPoolAddress(cfmm);
        uint256 inAmt0;
        uint256 inAmt1;
        uint256[] memory outAmts;
        {
            (uint256 reserve0, uint256 reserve1,) = IUniswapV2PairMinimal(store.cfmm).getReserves();
            (inAmt0, inAmt1, outAmts) = rebalancePosition(reserve0, reserve1, deltas[0], deltas[1]);
        }
        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] + inAmt0 - outAmts[0];
        _tokensHeld[1] = tokensHeld[1] + inAmt1 - outAmts[1];
        //ISendTokensCallback(msg.sender).sendTokensCallback(outAmts, cfmm);
        sendToken(store.tokens[0], store.cfmm, outAmts[0]);
        sendToken(store.tokens[1], store.cfmm, outAmts[1]);
        IUniswapV2PairMinimal(store.cfmm).swap(inAmt0,inAmt1,address(this), new bytes(0));/**/
    }

    function rebalancePosition(uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1) internal view returns(uint256 inAmt0, uint256 inAmt1, uint256[] memory outAmts) {
        require((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0), 'bad delta');
        outAmts = new uint256[](2);
        uint8 i;
        if(delta0 > 0 || delta1 > 0) {
            inAmt0 = uint256(delta1);//buy token1
            if(delta0 > 0) (inAmt0, reserve0, reserve1, i) = (uint256(delta0), reserve1, reserve0, 1);//buy token0
            outAmts[i]= getAmountOut(inAmt0, reserve0, reserve1);
            if(inAmt0 != uint256(delta0)) (inAmt1, inAmt0) = (inAmt0, inAmt1);
        } else {
            uint256 outAmt = uint256(-delta0);//sell token0
            if(delta1 < 0) (outAmt, reserve0, reserve1, i) = (uint256(-delta1), reserve1, reserve0, 1);//sell token1
            inAmt1 = getAmountIn(outAmt, reserve0, reserve1);
            outAmts[i] = outAmt;
            if(outAmt != uint256(-delta0)) (inAmt0, inAmt1) = (inAmt1, inAmt0);
        }
    }

    // selling exactly amountOut
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountIn(uint amountOut, uint reserveOut, uint reserveIn) internal view returns (uint amountIn) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint amountOutWithFee = amountOut * UniswapV2Storage.store().tradingFee2;
        uint numerator = amountOutWithFee * reserveIn;
        uint denominator = (reserveOut * UniswapV2Storage.store().tradingFee1) + amountOutWithFee;
        amountIn = numerator / denominator;
    }

    // buying exactly amountIn
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountOut(uint amountIn, uint reserveOut, uint reserveIn) internal view returns (uint amountOut) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint numerator = (reserveOut * amountIn) * UniswapV2Storage.store().tradingFee1;
        uint denominator = (reserveIn - amountIn) * UniswapV2Storage.store().tradingFee2;
        amountOut = (numerator / denominator) + 1;
    }
}
