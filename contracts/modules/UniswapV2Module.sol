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
}
