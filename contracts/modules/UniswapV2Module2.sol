// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseModule.sol";
import "../libraries/Math.sol";
import "../libraries/PoolAddress.sol";
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
    function addLiquidity(
        address cfmm,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin
    ) internal virtual returns (uint[] memory amounts, address payee) {
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

    //function getGammaPoolAddress(address cfmm) internal view returns(address gammaPool){
    //    gammaPool = PoolAddress.computeAddress(UniswapV2Storage.store().factory, PoolAddress.getPoolKey(cfmm, UniswapV2Storage.store().protocol));
    //    require(msg.sender == gammaPool, 'FORBIDDEN');
    //}

    //TODO: Can be delegated
    function mint(address cfmm, uint[] calldata amounts) internal virtual override returns(uint liquidity) {
        //address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        //liquidity = IUniswapV2PairMinimal(cfmm).mint(gammaPool);
    }

    //TODO: Can be delegated
    function burn(address cfmm, address to, uint256 amount) internal virtual override returns(uint[] memory amounts) {
        /*require(amount > 0, '0 amount');
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        uint256 balance0Before = GammaSwapLibrary.balanceOf(cfmm, cfmm);//maybe we can check here that the GP balance also decreased
        uint256 balance1Before = GammaSwapLibrary.balanceOf(cfmm, gammaPool);
        ISendLiquidityCallback(msg.sender).sendLiquidityCallback(cfmm, amount);
        require(balance0Before + amount <= GammaSwapLibrary.balanceOf(cfmm, cfmm), 'not received');
        require(balance1Before - amount <= GammaSwapLibrary.balanceOf(cfmm, gammaPool), 'not sent');
        amounts = new uint[](2);
        (amounts[0], amounts[1]) = IUniswapV2PairMinimal(cfmm).burn(to);/**/
    }

    function calcInvariant(address cfmm, uint[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }

    function repayLiquidity(address cfmm, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld, uint256[] memory amounts, uint256 _lpTokensPaid, uint256 _liquidityPaid) {
        /*address gammaPool = getGammaPoolAddress(cfmm);

        (amounts,,) = convertLiquidityToAmounts(cfmm, liquidity);
        require(tokensHeld[0] >= amounts[0] && tokensHeld[1] >= amounts[1], '< amounts');

        ISendTokensCallback(msg.sender).sendTokensCallback(amounts, cfmm);

        _lpTokensPaid = IUniswapV2PairMinimal(cfmm).mint(gammaPool);
        _liquidityPaid = _lpTokensPaid * calcCFMMTotalInvariant(cfmm) / GammaSwapLibrary.totalSupply(cfmm);

        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] - amounts[0];
        _tokensHeld[1] = tokensHeld[1] - amounts[1];/**/
    }

    function rebalancePosition(address cfmm, uint256 liquidity, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld){
        /*address gammaPool = getGammaPoolAddress(cfmm);

        uint256 reserve0;
        uint256 reserve1;
        uint256[] memory amounts;
        (amounts, reserve0, reserve1) = convertLiquidityToAmounts(cfmm, liquidity);

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
        ISendTokensCallback(msg.sender).sendTokensCallback(outAmts, cfmm);
        IUniswapV2PairMinimal(cfmm).swap(inAmt0,inAmt1, gammaPool, new bytes(0));/**/
    }

    function rebalancePosition(address cfmm, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual override returns(uint256[] memory _tokensHeld) {
        /*address gammaPool = getGammaPoolAddress(cfmm);
        uint256 inAmt0;
        uint256 inAmt1;
        uint256[] memory outAmts;
        {
            (uint256 reserve0, uint256 reserve1,) = IUniswapV2PairMinimal(cfmm).getReserves();
            (inAmt0, inAmt1, outAmts) = rebalancePosition(reserve0, reserve1, deltas[0], deltas[1]);
        }
        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] + inAmt0 - outAmts[0];
        _tokensHeld[1] = tokensHeld[1] + inAmt1 - outAmts[1];
        ISendTokensCallback(msg.sender).sendTokensCallback(outAmts, cfmm);
        IUniswapV2PairMinimal(cfmm).swap(inAmt0,inAmt1,gammaPool, new bytes(0));/**/
    }

    function rebalancePosition(UniswapV2Storage.UniswapV2Store storage store, uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1) internal view returns(uint256 inAmt0, uint256 inAmt1, uint256[] memory outAmts) {
        require((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0), 'bad delta');
        outAmts = new uint256[](2);
        uint8 i;
        if(delta0 > 0 || delta1 > 0) {
            inAmt0 = uint256(delta1);//buy token1
            if(delta0 > 0) (inAmt0, reserve0, reserve1, i) = (uint256(delta0), reserve1, reserve0, 1);//buy token0
            outAmts[i]= getAmountOut(store.tradingFee1, store.tradingFee2, inAmt0, reserve0, reserve1);
            if(inAmt0 != uint256(delta0)) (inAmt1, inAmt0) = (inAmt0, inAmt1);
        } else {
            uint256 outAmt = uint256(-delta0);//sell token0
            if(delta1 < 0) (outAmt, reserve0, reserve1, i) = (uint256(-delta1), reserve1, reserve0, 1);//sell token1
            inAmt1 = getAmountIn(store.tradingFee1, store.tradingFee2, outAmt, reserve0, reserve1);
            outAmts[i] = outAmt;
            if(outAmt != uint256(-delta0)) (inAmt0, inAmt1) = (inAmt1, inAmt0);
        }
    }

    // selling exactly amountOut
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountIn(uint256 tradingFee1, uint256 tradingFee2, uint amountOut, uint reserveOut, uint reserveIn) internal pure returns (uint amountIn) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint amountOutWithFee = amountOut * tradingFee2;
        uint numerator = amountOutWithFee * reserveIn;
        uint denominator = (reserveOut * tradingFee1) + amountOutWithFee;
        amountIn = numerator / denominator;
    }

    // buying exactly amountIn
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountOut(uint256 tradingFee1, uint256 tradingFee2, uint amountIn, uint reserveOut, uint reserveIn) internal pure returns (uint amountOut) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint numerator = (reserveOut * amountIn) * tradingFee1;
        uint denominator = (reserveIn - amountIn) * tradingFee2;
        amountOut = (numerator / denominator) + 1;
    }
}
