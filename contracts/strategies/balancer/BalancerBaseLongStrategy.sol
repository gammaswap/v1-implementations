// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../base/BaseLongStrategy.sol";
import "./BalancerBaseStrategy.sol";

import "../../libraries/Math.sol";

abstract contract BalancerBaseLongStrategy is BaseLongStrategy, BalancerBaseStrategy {
    error BadDelta();
    error ZeroReserves();

    uint16 immutable public origFee;
    uint16 immutable public LTV_THRESHOLD;
    uint16 immutable public tradingFee;

    constructor(uint16 _ltvThreshold, uint256 _blocksPerYear, uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseStrategy(_blocksPerYear, _baseRate, _factor, _maxApy) {
        LTV_THRESHOLD = _ltvThreshold;
        origFee = _originationFee;
        tradingFee = _tradingFee1;
    }

    function ltvThreshold() internal virtual override view returns(uint16) {
        return LTV_THRESHOLD;
    }

    function originationFee() internal virtual override view returns(uint16) {
        return origFee;
    }

    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        uint256[] memory weights = getWeights(s.cfmm);

        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        amounts[0] = Math.power(liquidity / lastCFMMInvariant, 1e18 / weights[0]) * s.CFMM_RESERVES[0];
        amounts[1] = Math.power(liquidity / lastCFMMInvariant, 1e18 / weights[1]) * s.CFMM_RESERVES[1];
    }

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
        sendTokens(_loan, s.cfmm, amounts);
    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        // IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
        //     poolId: getPoolId(s.cfmm),
        //     kind: IVault.SwapKind.GIVEN_IN,
        //     assetIn: s.CFMM_TOKENS[0],
        //     assetOut: s.CFMM_TOKENS[1],
        //     amount: inAmts[0],
        //     userData: abi.encode(outAmts[1])
        // });

        // IVault.FundManagement memory fundManagement = IVault.FundManagement({
        //     sender;
        //     fromInternalBalance;
        //     recipient;
        //     toInternalBalance;
        // }
        
        // TODO: Implement this for Balancer
        // IVault(getVault(cfmm)).swap(singleSwap, funds, new bytes(0), address(this)
    }

    // TODO: What is this function doing exactly?
    // Uniswap: Send tokens first before calling Pool.swap
    // Balancer: ??
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
