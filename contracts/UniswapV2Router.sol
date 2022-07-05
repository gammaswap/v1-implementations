pragma solidity ^0.8.0;
pragma abicoder v2;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "./IProtocolRouter.sol";
import "./IAddLiquidityCallback.sol";

contract UniswapV2Router is IProtocolRouter {

    address public immutable override factory;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory) public {
        factory = _factory;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal pure returns (address pair) {
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) internal view returns (address pair, uint reserveA, uint reserveB) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = pairFor(token0, token1);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(token0, token1)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB, address pool) {
        // create the pair if it doesn't exist yet
        (address pair, uint reserveA, uint reserveB) = getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
        pool = pair;
    }/*
    Pool:
        -tokens (A, B, ..., etc)
        -protocol
    */
    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balanceOf(address token, address pool) private view returns (uint256) {
        (bool success, bytes memory data) =
        token.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, pool));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function addLiquidity(AddLiquidityParams params, bytes calldata data) external virtual override ensure(params.deadline) returns (uint amountA, uint amountB, uint liquidity, address pool) {
        (amountA, amountB, pool) = _addLiquidity(params.tokenA, params.tokenB, params.amountADesired, params.amountBDesired, params.amountAMin, params.amountBMin);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amountA > 0) balance0Before = balanceOf(params.tokenA, pool);
        if (amountB > 0) balance1Before = balanceOf(params.tokenB, pool);
        IAddLiquidityCallback(msg.sender).addLiquidityCallback(amountA, amountB, data);
        if (amountA > 0) require(balance0Before.add(amountA) <= balanceOf(params.tokenA, pool), 'M0');
        if (amountB > 0) require(balance1Before.add(amountB) <= balanceOf(params.tokenB, pool), 'M1');

        liquidity = IUniswapV2Pair(uniPool).mint(params.gammaPool);

    }
}
