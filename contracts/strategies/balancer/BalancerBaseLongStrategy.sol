// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../base/BaseLongStrategy.sol";
import "./BalancerBaseStrategy.sol";

import "../../libraries/Math.sol";
import "../../libraries/weighted/FixedPoint.sol";
import "../../libraries/weighted/WeightedMath.sol";

abstract contract BalancerBaseLongStrategy is BaseLongStrategy, BalancerBaseStrategy {
    error BadDelta();
    error ZeroReserves();

    uint16 immutable public origFee;
    uint16 immutable public LTV_THRESHOLD;
    uint16 immutable public tradingFee1;
    uint16 immutable public tradingFee2;

    constructor(uint16 _ltvThreshold, uint256 _blocksPerYear, uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseStrategy(_blocksPerYear, _baseRate, _factor, _maxApy) {
        LTV_THRESHOLD = _ltvThreshold;
        origFee = _originationFee;
        tradingFee1 = _tradingFee1;
        tradingFee2 = _tradingFee2;
    }

    function ltvThreshold() internal virtual override view returns(uint16) {
        return LTV_THRESHOLD;
    }

    function originationFee() internal virtual override view returns(uint16) {
        return origFee;
    }

    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;

        // This has been unmodified from the Uniswap implementation
        amounts[0] = (liquidity * s.CFMM_RESERVES[0] / lastCFMMInvariant);
        amounts[1] = (liquidity * s.CFMM_RESERVES[1] / lastCFMMInvariant);
    }

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
        // See the corresponding function in BaseLongStrategy.sol for notes on Balancer
    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address assetIn;
        address assetOut;
        uint256 amountIn;
        uint256 amountOut;

        address[] memory tokens = getTokens(s.cfmm);

        // NOTE: inAmts is the quantity of tokens going INTO the GammaPool
        // outAmts is the quantity of tokens going OUT OF the GammaPool

        // Parse the function inputs to determine which direction and outputs are expected
        if (outAmts[0] == 0) {
            assetIn = tokens[1];
            assetOut = tokens[0];
            amountIn = outAmts[1];
            amountOut = inAmts[0];
        } else if (outAmts[1] == 0) {
            assetIn = tokens[0];
            assetOut = tokens[1];
            amountIn = outAmts[0];
            amountOut = inAmts[1];
        } else {
            revert("The parameter outAmts is not defined correctly.");
        }

        IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
            poolId: getPoolId(s.cfmm),
            kind: uint256(IVault.SwapKind.GIVEN_IN),
            assetIn: assetIn,
            assetOut: assetOut,
            amount: amountIn,
            userData: abi.encode(amountOut)
        });

        IVault.FundManagement memory fundManagement = IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: address(this), // address(this) is correct but GammaPool is not payable
            toInternalBalance: false
        });
        
        IVault(getVault(s.cfmm)).swap(singleSwap, fundManagement, amountOut, block.timestamp);
    }

    // Determines the amounts of tokens in and out expected
    // TODO: Balancer has a utils contract we can use to query this
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);

        // NOTE: inAmts is the quantity of tokens going INTO the GammaPool
        // outAmts is the quantity of tokens going OUT OF the GammaPool

        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = calcInAndOutAmounts(_loan, s.CFMM_RESERVES[0], s.CFMM_RESERVES[1], deltas[0], deltas[1]);
    }

    struct ActualAmtOutArguments {
        IERC20 token;
        address to;
        uint256 amount;
        uint256 balance;
        uint256 collateral;
    }

    /**
     * @dev Calculates the expected bought and sold amounts corresponding to a change in collateral given by delta.
     *      This calculation depends on the reserves existing in the Balancer pool.
     * @param _loan Liquidity loan whose collateral will be used to calculate the swap amounts
     * @param reserve0 The amount of reserve token0 in the Balancer pool
     * @param reserve1 The amount of reserve token1 in the Balancer pool
     * @param delta0 The desired amount of collateral token0 from the loan to swap (> 0 buy, < 0 sell, 0 ignore)
     * @param delta1 The desired amount of collateral token1 from the loan to swap (> 0 buy, < 0 sell, 0 ignore)
     * @return inAmt0 The expected amount of token0 to receive from the Balancer pool (corresponding to a buy)
     * @return inAmt1 The expected amount of token1 to receive from the Balancer pool (corresponding to a buy)
     * @return outAmt0 The expected amount of token0 to send to the Balancer pool (corresponding to a sell)
     * @return outAmt1 The expected amount of token1 to send to the Balancer pool (corresponding to a sell)
     */
    function calcInAndOutAmounts(LibStorage.Loan storage _loan, uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1)
        internal returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        if(!((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0))) {
            revert BadDelta();
        }

        if(reserve0 == 0 || reserve1 == 0) {
            revert ZeroReserves();
        }

        // Get the Balancer weights and re-org them to represent in and out weights
        uint256[] memory weights = getWeights(s.cfmm);
        uint256 weightIn = delta0 > 0 ? weights[0] : weights[1];
        uint256 weightOut = delta0 > 0 ? weights[1] : weights[0];

        // If the delta is positive, then we are buying a token from the Balancer pool
        if (delta0 > 0 || delta1 > 0) {
            // Then the first token corresponds to the token that the GammaPool is getting from the Balancer pool
            uint256 amountIn = delta0 > 0 ? uint256(delta0) : uint256(delta1);
            uint256 reserveIn = delta0 > 0 ? reserve0 : reserve1;
            uint256 reserveOut = delta0 > 0 ? reserve1 : reserve0;
            // uint256 tokenIndex = delta0 > 0 ? 1 : 0;

            uint256 amountOut = getAmountIn(amountIn, reserveIn, weightIn, reserveOut, weightOut);
            // uint256 actualAmountOut = calcActualOutAmt(ActualAmtOutArguments(IERC20(s.tokens[tokenIndex]), s.cfmm, amountOut, s.TOKEN_BALANCE[tokenIndex], _loan.tokensHeld[tokenIndex]));

            // // If the actual amount out is less than the amount out, then we need to adjust the amount in
            // if (actualAmountOut < amountOut) {
            //     amountOut = actualAmountOut;
            //     amountIn = getAmountOut(amountOut, reserveIn, weightIn, reserveOut, weightOut);
            // }

            // Assigning values to the return variables
            inAmt0 = delta0 > 0 ? amountIn : 0;
            inAmt1 = delta0 > 0 ? 0 : amountIn;
            outAmt0 = delta0 > 0 ? 0 : amountOut;
            outAmt1 = delta0 > 0 ? amountOut : 0;
        } else {
            // If the delta is negative, then we are selling a token to the Balancer pool
            uint256 amountIn = delta0 < 0 ? uint256(-delta0) : uint256(-delta1);
            uint256 reserveIn = delta0 < 0 ? reserve0 : reserve1;
            uint256 reserveOut = delta0 < 0 ? reserve1 : reserve0;
            // uint256 tokenIndex = delta0 < 0 ? 0 : 1;

            // uint256 actualAmountOut = calcActualOutAmt(ActualAmtOutArguments(IERC20(s.tokens[tokenIndex]), s.cfmm, amountIn, s.TOKEN_BALANCE[tokenIndex], _loan.tokensHeld[tokenIndex]));
            uint256 amountOut = getAmountOut(amountIn, reserveIn, weightIn, reserveOut, weightOut);

            // Assigning values to the return variables
            inAmt0 = delta0 < 0 ? 0 : amountOut;
            inAmt1 = delta0 < 0 ? amountOut : 0;
            outAmt0 = delta0 < 0 ? amountIn : 0;
            outAmt1 = delta0 < 0 ? 0 : amountIn;
        }
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
        // Revert if the sum of normalised weights is not equal to 1
        // Error code is BAL#308
        require(weightOut + weightIn == FixedPoint.ONE, "BAL#308");
        return WeightedMath._calcInGivenOut(reserveIn, weightIn, reserveOut, weightOut, amountOut);
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
        // Revert if the sum of normalised weights is not equal to 1
        // Error code is BAL#308
        require(weightOut + weightIn == FixedPoint.ONE, "BAL#308");
        return WeightedMath._calcOutGivenIn(reserveIn, weightIn, reserveOut, weightOut, amountIn);
    }
}
