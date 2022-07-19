// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/external/IUniswapV2PairMinimal.sol";
import "../interfaces/IProtocolModule.sol";
import "../interfaces/ISendLiquidityCallback.sol";
import "../interfaces/ISendTokensCallback.sol";
import "../libraries/GammaSwapLibrary.sol";
import "../libraries/PoolAddress.sol";
import "../libraries/Math.sol";

contract UniswapV2Module is IProtocolModule {

    uint256 private immutable ONE = 10**18;
    address public immutable override factory;//protocol factory
    address public immutable override protocolFactory;//protocol factory
    uint24 public immutable override protocol;

    uint16 public immutable tradingFee1 = 1000;
    uint16 public immutable tradingFee2 = 997;

    uint256 public immutable BASE_RATE = 10**16;
    uint256 public immutable OPTIMAL_UTILIZATION_RATE = 8*(10**17);
    uint256 public immutable SLOPE1 = 10**18;
    uint256 public immutable SLOPE2 = 10**18;

    uint256 public immutable YEAR_BLOCK_COUNT = 2252571;

    constructor(address _factory, address _protocolFactory, uint24 _protocol) {
        factory = _factory;
        protocolFactory = _protocolFactory;
        protocol = _protocol;
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

    function validateCFMM(address[] calldata _tokens, address _cfmm) external view override returns(address[] memory tokens, bytes32 key){
        require(isContract(_cfmm) == true, 'not contract');
        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        require(_cfmm == pairFor(tokens[0], tokens[1]), 'bad protocol');
        key = PoolAddress.getPoolKey(_cfmm, protocol);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal virtual view returns (address pair) {
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                protocolFactory,
                keccak256(abi.encodePacked(tokenA, tokenB)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) internal view returns (address pair, uint reserveA, uint reserveB) {
        (address token0, address token1) = GammaSwapLibrary.sortTokens(tokenA, tokenB);
        pair = pairFor(token0, token1);
        (uint reserve0, uint reserve1,) = IUniswapV2PairMinimal(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, '> amount');
        require(reserveA > 0 && reserveB > 0, '0 reserve');
        amountB = (amountA * reserveB) / reserveA;
    }

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal pure returns(uint256) {
        uint256 utilizationRate = (lpBorrowed * ONE) / (lpBalance + lpBorrowed);
        if(utilizationRate <= OPTIMAL_UTILIZATION_RATE) {
            uint256 variableRate = (utilizationRate * SLOPE1) / OPTIMAL_UTILIZATION_RATE;
            return (BASE_RATE + variableRate);
        } else {
            uint256 utilizationRateDiff = utilizationRate - OPTIMAL_UTILIZATION_RATE;
            uint256 variableRate = (utilizationRateDiff * SLOPE2) / (ONE - OPTIMAL_UTILIZATION_RATE);
            return(BASE_RATE + SLOPE1 + variableRate);
        }
    }

    function calcNewDevShares(address cfmm, uint256 devFee, uint256 lastFeeIndex, uint256 totalSupply, uint256 LP_TOKEN_BALANCE, uint256 BORROWED_INVARIANT) external view virtual override returns(uint256) {
        (uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();
        uint256 cfmmTotalInvariant = Math.sqrt(reserveA * reserveB);
        uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
        uint256 totalInvariantInCFMM = ((LP_TOKEN_BALANCE * cfmmTotalInvariant) / cfmmTotalSupply);//How much Invariant does this contract have from LP_TOKEN_BALANCE
        uint256 factor = ((lastFeeIndex - ONE) * devFee) / lastFeeIndex;//Percentage of the current growth that we will give to devs
        uint256 accGrowth = (factor * BORROWED_INVARIANT) / (BORROWED_INVARIANT + totalInvariantInCFMM);
        return (totalSupply * accGrowth) / (ONE - accGrowth);
    }

    function calcCFMMTotalInvariant(address cfmm) internal view returns(uint256) {
        (uint256 reserveA, uint256 reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();//TODO: This might need a check to make sure that (reserveA * reserveB) do not overflow
        return Math.sqrt(reserveA * reserveB);
    }

    function getCFMMTotalInvariant(address cfmm) external view virtual override returns(uint256) {
        return calcCFMMTotalInvariant(cfmm);
    }

    function getCFMMYield(address cfmm, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lpBalance, uint256 lpBorrowed, uint256 lastBlockNum) external view virtual override
        returns(uint256 lastFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 borrowRate) {
        borrowRate = calcBorrowRate(lpBalance, lpBorrowed);
        lastCFMMInvariant = calcCFMMTotalInvariant(cfmm);
        lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
        if(lastCFMMTotalSupply > 0) {
            uint256 denominator = (prevCFMMInvariant * lastCFMMTotalSupply) / ONE;
            lastCFMMFeeIndex = (lastCFMMInvariant * prevCFMMTotalSupply) / denominator;
        } else {
            lastCFMMFeeIndex = ONE;
        }

        if(lastCFMMFeeIndex > 0) {
            uint256 blockDiff = block.number - lastBlockNum;
            uint256 adjBorrowRate = (blockDiff * borrowRate) / YEAR_BLOCK_COUNT;
            lastFeeIndex = lastCFMMFeeIndex + adjBorrowRate;
        } else {
            lastFeeIndex = ONE;
        }

    }

    function addLiquidity(
        address cfmm,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin
    ) external virtual override returns (uint[] memory amounts, address payee) {
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

    function getGammaPoolAddress(address cfmm) internal view returns(address gammaPool){
        gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        require(msg.sender == gammaPool, 'FORBIDDEN');
    }

    function mint(address cfmm, uint[] calldata amounts) external virtual override returns(uint liquidity) {
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        liquidity = IUniswapV2PairMinimal(cfmm).mint(gammaPool);
    }

    function burn(address cfmm, address to, uint256 amount) external virtual override returns(uint[] memory amounts) {
        require(amount > 0, '0 amount');
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        uint256 balance0Before = GammaSwapLibrary.balanceOf(cfmm, cfmm);//maybe we can check here that the GP balance also decreased
        uint256 balance1Before = GammaSwapLibrary.balanceOf(cfmm, gammaPool);
        ISendLiquidityCallback(msg.sender).sendLiquidityCallback(cfmm, amount);
        require(balance0Before + amount <= GammaSwapLibrary.balanceOf(cfmm, cfmm), 'not received');
        require(balance1Before - amount <= GammaSwapLibrary.balanceOf(cfmm, gammaPool), 'not sent');
        amounts = new uint[](2);
        (amounts[0], amounts[1]) = IUniswapV2PairMinimal(cfmm).burn(to);
    }

    function calcInvariant(address cfmm, uint[] calldata amounts) external virtual override view returns(uint) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }

    //See if can use separate functions one that returns amoutns only and one reserves too, but without using arrays to save memory in the filesize
    function convertLiquidityToAmounts(address cfmm, uint256 liquidity) internal view returns(uint256[] memory amounts, uint256 reserve0, uint256 reserve1) {
        (reserve0, reserve1,) = IUniswapV2PairMinimal(cfmm).getReserves();
        amounts = new uint256[](2);
        uint256 cfmmInvariant = Math.sqrt(reserve0 * reserve1);
        amounts[0] = liquidity * reserve0 / cfmmInvariant;
        amounts[1] = liquidity * reserve1 / cfmmInvariant;
    }

    function repayLiquidity(address cfmm, uint256 liquidity, uint256[] calldata tokensHeld) external virtual override returns(uint256[] memory _tokensHeld, uint256[] memory amounts, uint256 _lpTokensPaid, uint256 _liquidityPaid) {
        address gammaPool = getGammaPoolAddress(cfmm);

        (amounts,,) = convertLiquidityToAmounts(cfmm, liquidity);
        require(tokensHeld[0] >= amounts[0] && tokensHeld[1] >= amounts[1], '< amounts');

        ISendTokensCallback(msg.sender).sendTokensCallback(amounts, cfmm);

        _lpTokensPaid = IUniswapV2PairMinimal(cfmm).mint(gammaPool);
        _liquidityPaid = _lpTokensPaid * calcCFMMTotalInvariant(cfmm) / GammaSwapLibrary.totalSupply(cfmm);

        _tokensHeld = new uint256[](2);
        _tokensHeld[0] = tokensHeld[0] - amounts[0];
        _tokensHeld[1] = tokensHeld[1] - amounts[1];
    }

    function rebalancePosition(address cfmm, uint256 liquidity, uint256[] calldata tokensHeld) external virtual override returns(uint256[] memory _tokensHeld){
        address gammaPool = getGammaPoolAddress(cfmm);

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
        IUniswapV2PairMinimal(cfmm).swap(inAmt0,inAmt1, gammaPool, new bytes(0));
    }

    function rebalancePosition(address cfmm, int256[] calldata deltas, uint256[] calldata tokensHeld) external virtual override returns(uint256[] memory _tokensHeld) {
        address gammaPool = getGammaPoolAddress(cfmm);
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
        IUniswapV2PairMinimal(cfmm).swap(inAmt0,inAmt1,gammaPool, new bytes(0));
    }

    function rebalancePosition(uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1) internal pure returns(uint256 inAmt0, uint256 inAmt1, uint256[] memory outAmts) {
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
    function getAmountIn(uint amountOut, uint reserveOut, uint reserveIn) internal pure returns (uint amountIn) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint amountOutWithFee = amountOut * tradingFee2;
        uint numerator = amountOutWithFee * reserveIn;
        uint denominator = (reserveOut * tradingFee1) + amountOutWithFee;
        amountIn = numerator / denominator;
    }

    // buying exactly amountIn
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountOut(uint amountIn, uint reserveOut, uint reserveIn) internal pure returns (uint amountOut) {
        require(reserveOut > 0 && reserveIn > 0, '0 reserve');
        uint numerator = (reserveOut * amountIn) * tradingFee1;
        uint denominator = (reserveIn - amountIn) * tradingFee2;
        amountOut = (numerator / denominator) + 1;
    }
}
