// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/external/IUniswapV2PairMinimal.sol";
import "../interfaces/IProtocolModule.sol";
import "../interfaces/IRemoveLiquidityCallback.sol";
import "../PositionManager.sol";
import "../interfaces/IPositionManager.sol";
import "../libraries/GammaSwapLibrary.sol";
import "../libraries/PoolAddress.sol";
import "../libraries/Math.sol";

contract UniswapV2Module is IProtocolModule {

    uint256 private immutable ONE = 10**18;
    address public immutable override factory;//protocol factory
    address public immutable override protocolFactory;//protocol factory
    uint24 public override protocol;

    uint16 public immutable tradingFee1 = 1000;
    uint16 public immutable tradingFee2 = 997;

    uint256 public BASE_RATE = 10**16;
    uint256 public OPTIMAL_UTILIZATION_RATE = 8*(10**17);
    uint256 public SLOPE1 = 10**18;
    uint256 public SLOPE2 = 10**18;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'M1: EXPIRED');
        _;
    }

    constructor(address _factory, address _protocolFactory) {
        factory = _factory;
        protocolFactory = _protocolFactory;
        protocol = 1;
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
        require(_cfmm != address(0), 'M1: CFMM_ZERO_ADDRESS');
        require(isContract(_cfmm) == true, 'M1: CFMM_DOES_NOT_EXIST');/**/
        require(_tokens.length == 2, 'M1: INVALID_NUMBER_OF_TOKENS');
        require(_tokens[0] != _tokens[1], 'M1: IDENTICAL_ADDRESSES');
        require(_tokens[0] != address(0) && _tokens[1] != address(0), 'M1: ZERO_ADDRESS');
        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[1]);//For Uniswap and its clones the user passes the parameters
        require(_cfmm == pairFor(tokens[0], tokens[1]), 'M1: INVALID_PROTOCOL_FOR_CFMM');
        key = PoolAddress.getPoolKey(_cfmm, protocol);
    }

    function getKey(address _cfmm) external view override returns(bytes32 key) {
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
        require(amountA > 0, 'M1: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'M1: INSUFFICIENT_LIQUIDITY');
        amountB = (amountA * reserveB) / reserveA;
    }

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) external virtual override view returns(uint256) {
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

    function getCFMMTotalInvariant(address cfmm) external view virtual override returns(uint256) {
        (uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();//TODO: This might need a check to make sure that (reserveA * reserveB) do not overflow
         return Math.sqrt(reserveA * reserveB);
    }

    function getCFMMYield(address cfmm, uint256 prevInvariant, uint256 prevTotalSupply) external view virtual override returns(uint256 lastFeeIndex, uint256 lastInvariant, uint256 lastTotalSupply) {
        (uint256 reserveA, uint256 reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();
        lastInvariant = Math.sqrt(reserveA * reserveB);//TODO: This might need a check to make sure that (reserveA * reserveB) do not overflow
        lastTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
        if(lastTotalSupply > 0) {
            uint256 denominator = (prevInvariant * lastTotalSupply) / ONE;
            lastFeeIndex = (lastInvariant * prevTotalSupply) / denominator;
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
                require(amountBOptimal >= amountsMin[1], 'M1: INSUFFICIENT_B_AMOUNT');
                (amounts[0], amounts[1]) = (amountsDesired[0], amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountsDesired[1], reserveB, reserveA);
                assert(amountAOptimal <= amountsDesired[0]);
                require(amountAOptimal >= amountsMin[0], 'M1: INSUFFICIENT_A_AMOUNT');
                (amounts[0], amounts[1]) = (amountAOptimal, amountsDesired[1]);
            }
        }
    }

    function mint(address cfmm, uint[] calldata amounts) external virtual override returns(uint liquidity) {
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        liquidity = IUniswapV2PairMinimal(cfmm).mint(gammaPool);
    }

    function burn(address cfmm, address to, uint256 amount) external virtual override returns(uint[] memory amounts) {
        require(amount > 0, 'M1: ZERO_AMOUNT');
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        uint256 balance0Before = GammaSwapLibrary.balanceOf(cfmm, cfmm);//maybe we can check here that the GP balance also decreased
        uint256 balance1Before = GammaSwapLibrary.balanceOf(cfmm, gammaPool);
        IRemoveLiquidityCallback(msg.sender).removeLiquidityCallback(cfmm, amount);
        require(balance0Before + amount <= GammaSwapLibrary.balanceOf(cfmm, cfmm), "M1: NO_TRANSFER0");
        require(balance1Before - amount <= GammaSwapLibrary.balanceOf(cfmm, gammaPool), "M1: NO_TRANSFER1");
        amounts = new uint[](2);
        (amounts[0], amounts[1]) = IUniswapV2PairMinimal(cfmm).burn(to);
    }

    function calcInvariant(address cfmm, uint[] calldata amounts) external virtual override view returns(uint) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }

    //TODO: Finish this
    function checkCollateral(address cfmm, uint[] calldata tokensHeld, uint256 invariantBorrowed) external virtual override view returns(bool) {
        //Must calculate the max loss price of tokensHeld to see how far are we covered. If the liquidity we've provided is sufficient
        //Must use that formula that checks the ratio of the tokensHeld and calculates the maxLoss price and what the liquidity is at that price to protect against flash loan attacks
        return true;
    }

    function convertLiquidityToAmounts(address cfmm, uint256 liquidity) external virtual override view returns(uint256[] memory amounts) {
        (uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();
        amounts = new uint256[](2);
        uint256 cfmmInvariant = Math.sqrt(reserveA * reserveB);
        amounts[0] = liquidity * reserveA / cfmmInvariant;
        amounts[1] = liquidity * reserveB / cfmmInvariant;
    }

    function getPositionDeltaAndAmounts(address cfmm, uint256 liquidity, uint256[] calldata tokensHeld) external virtual override view returns(uint256[] memory deltaAmts, uint256[] memory amounts){
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        require(msg.sender == gammaPool);

        uint256[] memory reserves = new uint256[](2);
        (reserves[0], reserves[1],) = IUniswapV2PairMinimal(cfmm).getReserves();
        uint256 currPx = reserves[1] * ONE / reserves[0];
        uint256 initPx = tokensHeld[1] * ONE / tokensHeld[0];

        amounts = new uint256[](2);
        uint cfmmInvariant = Math.sqrt(reserves[0] * reserves[1]);
        amounts[0] = liquidity * reserves[0] / cfmmInvariant;
        amounts[1] = liquidity * reserves[1] / cfmmInvariant;

        deltaAmts = new uint256[](2);
        if (currPx > initPx) {//we sell token0
            deltaAmts[1] = liquidity * (Math.sqrt(currPx * ONE) - Math.sqrt(initPx * ONE));
            deltaAmts[0]= getAmountIn(deltaAmts[1], reserves[0], reserves[1]);
        } else if(currPx < initPx) {//we sell token1
            deltaAmts[0] = liquidity * (ONE - Math.sqrt((currPx * ONE / initPx) * ONE)) / Math.sqrt(currPx * ONE);
            deltaAmts[1] = getAmountIn(deltaAmts[0], reserves[1], reserves[0]);
        }
        //IUniswapV2PairMinimal(cfmm).swap(deltaAmts[0],deltaAmts[1], gammaPool, new bytes(0));
    }

    /*function getPositionAmounts(address cfmm, uint256 liquidity, uint256[] calldata tokensHeld) external virtual override view returns(uint256[] memory deltaAmts, uint256[] memory amounts){
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        require(msg.sender == gammaPool);

        uint256[] memory reserves = new uint256[](2);
        (reserves[0], reserves[1],) = IUniswapV2PairMinimal(cfmm).getReserves();
        uint256 currPx = reserves[1] * ONE / reserves[0];
        uint256 initPx = tokensHeld[1] * ONE / tokensHeld[0];

        amounts = new uint256[](2);
        uint cfmmInvariant = Math.sqrt(reserves[0] * reserves[1]);
        amounts[0] = liquidity * reserves[0] / cfmmInvariant;
        amounts[1] = liquidity * reserves[1] / cfmmInvariant;

        deltaAmts = new uint256[](2);
        if(amounts[0] > tokensHeld[0]) {

        } else if(amounts[1] > tokensHeld[1]) {

        }
        if (currPx > initPx) {//we sell token0
            deltaAmts[1] = liquidity * (Math.sqrt(currPx * ONE) - Math.sqrt(initPx * ONE));
            deltaAmts[0]= getAmountIn(deltaAmts[1], reserves[0], reserves[1]);
        } else if(currPx < initPx) {//we sell token1
            deltaAmts[0] = liquidity * (ONE - Math.sqrt((currPx * ONE / initPx) * ONE)) / Math.sqrt(currPx * ONE);
            deltaAmts[1] = getAmountIn(deltaAmts[0], reserves[1], reserves[0]);
        }
        //IUniswapV2PairMinimal(cfmm).swap(deltaAmts[0],deltaAmts[1], gammaPool, new bytes(0));
    }/**/

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function swapTokensForExactTokens(
        address cfmm,
        uint amountOut,
        uint amountInMax,
        bool isToken0,
        address tokenIn,
        uint256 reserveIn,
        uint256 reserveOut,
        address to
    ) internal virtual returns (uint amountIn) {
        amountIn = getAmountIn(amountOut, reserveIn, reserveOut);
        require(amountIn <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, cfmm, amountIn);//This has to work with a callback to GP
        (uint amount0Out, uint amount1Out) = isToken0 ? (uint(0), amountOut) : (amountOut, uint(0));
        IUniswapV2PairMinimal(cfmm).swap(amount0Out, amount1Out, to, new bytes(0));
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * tradingFee2;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * tradingFee1) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = (reserveIn * amountOut) * tradingFee1;
        uint denominator = (reserveOut - amountOut) * tradingFee2;
        amountIn = (numerator / denominator) + 1;
    }
}
