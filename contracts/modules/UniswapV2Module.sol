// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/external/IUniswapV2PairMinimal.sol";
import "../interfaces/IProtocolModule.sol";
import "../interfaces/IAddLiquidityCallback.sol";
import "../PositionManager.sol";
import "../interfaces/IPositionManager.sol";
import "../libraries/GammaSwapLibrary.sol";
import "../libraries/PoolAddress.sol";
import "../libraries/Math.sol";
import "../interfaces/IAddLiquidityCallback.sol";

contract UniswapV2Module is IProtocolModule {

    address public immutable override factory;//protocol factory
    address public immutable override protocolFactory;//protocol factory
    uint24 public override protocol;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _protocolFactory) {
        factory = _factory;
        protocolFactory = _protocolFactory;
        protocol = 1;
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external view override returns(address[] memory tokens){
        require(_tokens.length == 2, 'UniswapV2Module.validateParams: INVALID_NUMBER_OF_TOKENS');
        require(_tokens[0] != _tokens[1], 'UniswapV2Module.validateParams: IDENTICAL_ADDRESSES');
        require(_tokens[0] != address(0) && _tokens[1] != address(0), 'UniswapV2Module.validateParams: ZERO_ADDRESS');
        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[1]);//For Uniswap and its clones the user passes the parameters
        require(_cfmm == pairFor(tokens[0], tokens[1]), 'UniswapV2Module.validateParams: INVALID_PROTOCOL_FOR_CFMM');
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
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = (amountA * reserveB) / reserveA;
    }

    function getCFMMTotalInvariant(address cfmm) external view virtual override returns(uint256) {
        (uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();//TODO: This might need a check to make sure that (reserveA * reserveB) do not overflow
         return Math.sqrt(reserveA * reserveB);
    }

    function getCFMMInvariantChanges(address cfmm, uint256 prevLPBal, uint256 curLPBal) external view override returns(uint256 totalInvariantInCFMM, uint256 depositedInvariant) {
        uint256 depLPBal = curLPBal - prevLPBal;
        uint256 totalSupply = GammaSwapLibrary.totalSupply(cfmm);
        (uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();//TODO: This might need a check to make sure that (reserveA * reserveB) do not overflow
        uint256 totalCFMMInvariant = Math.sqrt(reserveA * reserveB);
        totalInvariantInCFMM = (prevLPBal * totalCFMMInvariant) / totalSupply;
        if (depLPBal > 0) {
            depositedInvariant = (depLPBal * totalCFMMInvariant) / totalSupply;
        }
    }

    /*function transferTokens(address payer, address payee, address[] memory tokens, uint[] memory amounts) internal virtual {
        uint balance0Before;
        uint balance1Before;
        if (amounts[0] > 0) balance0Before = GammaSwapLibrary.balanceOf(tokens[0], payee);
        if (amounts[1] > 0) balance1Before = GammaSwapLibrary.balanceOf(tokens[1], payee);
        IAddLiquidityCallback(msg.sender).addLiquidityCallback(protocol, tokens, amounts, payer, payee);
        if (amounts[0] > 0) require(balance0Before + amounts[0] <= GammaSwapLibrary.balanceOf(tokens[0], payee), 'M0');
        if (amounts[1] > 0) require(balance1Before + amounts[1] <= GammaSwapLibrary.balanceOf(tokens[1], payee), 'M1');
    }/**/

    function addLiquidity(
        address cfmm,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin
    ) external virtual override returns (uint[] memory amounts) {
        amounts = new uint[](2);
        (uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();
        if (reserveA == 0 && reserveB == 0) {
            (amounts[0], amounts[1]) = (amountsDesired[0], amountsDesired[1]);
        } else {
            uint amountBOptimal = quote(amountsDesired[0], reserveA, reserveB);
            if (amountBOptimal <= amountsDesired[1]) {
                require(amountBOptimal >= amountsMin[1], 'UniswapV2Module: INSUFFICIENT_B_AMOUNT');
                (amounts[0], amounts[1]) = (amountsDesired[0], amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountsDesired[1], reserveB, reserveA);
                assert(amountAOptimal <= amountsDesired[0]);
                require(amountAOptimal >= amountsMin[0], 'UniswapV2Module: INSUFFICIENT_A_AMOUNT');
                (amounts[0], amounts[1]) = (amountAOptimal, amountsDesired[1]);
            }
        }
    }

    function getPayee(address cfmm) external virtual override view returns(address) {
        return cfmm;
    }

    function mint(address cfmm, uint[] calldata amounts) external virtual override returns(uint liquidity) {
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        liquidity = IUniswapV2PairMinimal(cfmm).mint(gammaPool);
    }

    function burn(address cfmm, address to) external virtual override returns(uint[] memory amounts) {

    }
}
