// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../base/BaseLongStrategy.sol";
import "./BalancerBaseStrategy.sol";

abstract contract BalancerBaseLongStrategy is BaseLongStrategy, BalancerBaseStrategy {
    error BadDelta();
    error ZeroReserves();

    uint16 immutable public origFee;
    uint16 immutable public tradingFee;

    constructor(uint16 _originationFee, uint16 _tradingFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy, address _vault)
        BalancerBaseStrategy(_baseRate, _factor, _maxApy, _vault) {
        origFee = _originationFee;
        // TODO: Should we get this fee dynamically?
        tradingFee = _tradingFee;
    }

    function originationFee() internal virtual override view returns(uint16) {
        return origFee;
    }

    // TODO: Implement the corresponding logic for this for Balancer
    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        amounts[0] = liquidity * s.CFMM_RESERVES[0] / lastCFMMInvariant;
        amounts[1] = liquidity * s.CFMM_RESERVES[1] / lastCFMMInvariant;
    }

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
        sendTokens(_loan, s.cfmm, amounts);
    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        // TODO: Implement this for Balancer
    }

    // TODO: What is this function doing exactly?
    // Uniswap: Send tokens first before calling Pool.swap
    // Balancer: 
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = calcInAndOutAmounts(_loan, s.CFMM_RESERVES[0], s.CFMM_RESERVES[1], deltas[0], deltas[1]);
    }

    // TODO: What is this function doing exactly?
    function calcInAndOutAmounts(LibStorage.Loan storage _loan, uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1)
        internal returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        // TODO: Implement this for Balancer
    }

    // TODO: Add a function description for this function.
    function calcActualOutAmt(IERC20 token, address to, uint256 amount, uint256 balance, uint256 collateral) internal returns(uint256) {
        uint256 balanceBefore = GammaSwapLibrary.balanceOf(token, to);
        sendToken(token, to, amount, balance, collateral);
        return GammaSwapLibrary.balanceOf(token, to) - balanceBefore;
    }

    /**
     * @dev Calculates the amountIn amount required for an exact amountOut value according to the Balancer invariant formula.
     * @param amountOut The amount of token removed from the pool during the swap.
     * @param reserveOut The pool reserves for the token exiting the pool on the swap.
     * @param weightOut The normalised weight of the token exiting the pool on the swap.
     * @param reserveIn The pool reserves for the token entering the pool on the swap.
     * @param weightIn The normalised weight of the token entering the pool on the swap.
     */
    function getAmountIn(uint256 amountOut, uint256 reserveOut, uint256 weightOut, uint256 reserveIn, uint256 weightIn) internal view returns (uint256) {
        if(reserveOut == 0 || reserveIn == 0) {
            revert ZeroReserves();
        }

        uint256 base = reserveOut / (reserveOut - amountOut);
        uint256 exponent = weightOut / weightIn;
        uint256 power = Math.power(base, exponent);

        // Because the base is larger than one (and the power rounds up), the power should always be larger than one, so
        // the following subtraction should never revert.
        uint256 ratio = power - 1e18;

        return reserveIn * ratio / tradingFee;
    }

    /**
     * @dev Calculates the amountOut swap amount given for an exact amountIn value according to the Balancer invariant formula.
     * @param amountIn The amount of token swapped into the pool.
     * @param reserveOut The pool reserves for the token exiting the pool on the swap.
     * @param weightOut The normalised weight of the token exiting the pool on the swap.
     * @param reserveIn The pool reserves for the token entering the pool on the swap.
     * @param weightIn The normalised weight of the token entering the pool on the swap.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveOut, uint256 weightOut, uint256 reserveIn, uint256 weightIn) internal view returns (uint256) {
        if(reserveOut == 0 || reserveIn == 0) {
            revert ZeroReserves();
        }

        uint256 amountInWithFee = amountIn * tradingFee;
        uint256 denominator = reserveIn + amountInWithFee;

        uint256 base = reserveIn / denominator;
        uint256 exponent = weightIn / weightOut;
        uint256 power = Math.power(base, exponent);
        return reserveOut * (1e18 - power);
    }
}
