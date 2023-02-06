// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@gammaswap/v1-core/contracts/strategies/BaseLongStrategy.sol";
import "@gammaswap/v1-core/contracts/libraries/Math.sol";
import "../../libraries/weighted/FixedPoint.sol";
import "../../libraries/weighted/WeightedMath.sol";
import "./BalancerBaseStrategy.sol";

/**
 * @title Base Long Strategy concrete implementation contract for Balancer Weighted Pools
 * @author JakeXBT (https://github.com/JakeXBT)
 * @notice Common functions used by all concrete strategy implementations for Balancer Weighted Pools that need access to loans
 * @dev This implementation was specifically designed to work with Balancer Weighted Pools
 */
abstract contract BalancerBaseLongStrategy is BaseLongStrategy, BalancerBaseStrategy {
    error BadDelta();
    error ZeroReserves();

    /**
     * @return origFee Origination fee charged to every new loan that is issued.
     */
    uint16 immutable public origFee;

    /**
     * @return LTV_THRESHOLD Maximum Loan-To-Value ratio acceptable before a loan is eligible for liquidation.
     */
    uint16 immutable public LTV_THRESHOLD;

    /**
     * @return tradingFee1 Numerator in tradingFee calculation (e.g amount * tradingFee1 / tradingFee2).
     */
    uint16 immutable public tradingFee1;

    /**
     * @return tradingFee2 Denominator in tradingFee calculation (e.g amount * tradingFee1 / tradingFee2).
     */
    uint16 immutable public tradingFee2;

    /**
     * @dev Initializes the contract by setting `_ltvThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_originationFee`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
     */
    constructor(uint16 _ltvThreshold,  uint256 _maxTotalApy, uint256 _blocksPerYear, uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseStrategy(_maxTotalApy, _blocksPerYear, _baseRate, _factor, _maxApy) {
        LTV_THRESHOLD = _ltvThreshold;
        origFee = _originationFee;
        tradingFee1 = _tradingFee1;
        tradingFee2 = _tradingFee2;
    }

    /**
     * @dev See {BaseLongStrategy.ltvThreshold}.
     */
    function ltvThreshold() internal virtual override view returns(uint16) {
        return LTV_THRESHOLD;
    }

    /**
     * @dev See {BaseLongStrategy.originationFee}.
     */
    function originationFee() internal virtual override view returns(uint16) {
        return origFee;
    }

    /**
     * @dev Calculates the amount of tokens to repay a loan of quantity `liquidity` invariant units.
     * @param liquidity The amount of liquidity to repay the loan with.
     */
    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;

        // This has been unmodified from the Uniswap implementation
        amounts[0] = (liquidity * s.CFMM_RESERVES[0] / lastCFMMInvariant);
        amounts[1] = (liquidity * s.CFMM_RESERVES[1] / lastCFMMInvariant);
    }

    /**
     * @dev Empty implementation for Balancer. See {BaseLongStrategy.beforeRepay} for a discussion on the purpose of this function.
     */
    function beforeRepay(LibStorage.Loan storage, uint256[] memory) internal virtual override {
    }

    /**
     * @dev Swaps tokens with the Balancer Weighted Pool via the Vault contract.
     * @param outAmts The amount of each reserve token to swap out of the GammaPool.
     * @param inAmts The amount of each reserve token to swap into the GammaPool.
     */
    function swapTokens(LibStorage.Loan storage, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address assetIn;
        address assetOut;
        uint256 amountIn;
        uint256 amountOut;
        address _cfmm = s.cfmm;
        address[] memory tokens = getTokens(_cfmm);

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
            poolId: getPoolId(_cfmm),
            kind: uint8(IVault.SwapKind.GIVEN_IN),
            assetIn: assetIn,
            assetOut: assetOut,
            amount: amountIn,
            userData: bytes("0x")
        });

        IVault.FundManagement memory fundManagement = IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: address(this),
            toInternalBalance: false
        });

        // Adding approval for the Vault to spend the assetIn tokens
        addVaultApproval(assetIn, amountIn);

        IVault(getVault(_cfmm)).swap(singleSwap, fundManagement, 0, block.timestamp);
    }

    /**
     * @dev Check that there's enough collateral (`amount`) in the pool and the loan. If not revert
     * @param amount - amount to check
     * @param balance - total pool balance
     * @param collateral - total collateral in loan
     * @return _amount - same as `amount` if transaction did not revert
     */
    function checkAvailableCollateral(uint256 amount, uint256 balance, uint256 collateral) internal virtual pure returns(uint256){
        if(amount > balance) { // Check enough in pool's accounted balance
            revert NotEnoughBalance();
        }
        if(amount > collateral) { // Check enough collateral in loan
            revert NotEnoughCollateral();
        }
        return amount;
    }

    /**
     * @dev Calculates the expected bought and sold amounts corresponding to a change in collateral given by delta.
     * @param _loan Liquidity loan whose collateral will be used to calculate the swap amounts.
     * @param deltas The desired amount of collateral tokens from the loan to swap (> 0 buy, < 0 sell, 0 ignore).
     */
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);

        // NOTE: inAmts is the quantity of tokens going INTO the GammaPool
        // outAmts is the quantity of tokens going OUT OF the GammaPool

        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = calcInAndOutAmounts(s.CFMM_RESERVES[0], s.CFMM_RESERVES[1], deltas[0], deltas[1]);
        outAmts[0] = outAmts[0] > 0 ? checkAvailableCollateral(outAmts[0], s.TOKEN_BALANCE[0], _loan.tokensHeld[0]) : 0;
        outAmts[1] = outAmts[1] > 0 ? checkAvailableCollateral(outAmts[1], s.TOKEN_BALANCE[1], _loan.tokensHeld[1]) : 0;
    }

    /**
     * @dev Calculates the expected bought and sold amounts corresponding to a change in collateral given by delta.
     *      This calculation depends on the reserves existing in the Balancer pool.
     * @param reserve0 The amount of reserve token0 in the Balancer pool
     * @param reserve1 The amount of reserve token1 in the Balancer pool
     * @param delta0 The desired amount of collateral token0 from the loan to swap (> 0 buy, < 0 sell, 0 ignore)
     * @param delta1 The desired amount of collateral token1 from the loan to swap (> 0 buy, < 0 sell, 0 ignore)
     * @return inAmt0 The expected amount of token0 to receive from the Balancer pool (corresponding to a buy)
     * @return inAmt1 The expected amount of token1 to receive from the Balancer pool (corresponding to a buy)
     * @return outAmt0 The expected amount of token0 to send to the Balancer pool (corresponding to a sell)
     * @return outAmt1 The expected amount of token1 to send to the Balancer pool (corresponding to a sell)
     */
    function calcInAndOutAmounts(uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1)
        internal view returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
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

            uint256 amountOut = getAmountIn(amountIn, reserveIn, weightIn, reserveOut, weightOut);

            // Assigning values to the return variables
            inAmt0 = delta0 > 0 ? amountIn : 0;
            inAmt1 = delta0 > 0 ? 0 : amountIn;
            outAmt0 = delta0 > 0 ? 0 : amountOut;
            outAmt1 = delta0 > 0 ? amountOut : 0;
        } else {
            // If the delta is negative, then we are selling a token to the Balancer pool
            uint256 amountIn = delta0 < 0 ? uint256(-delta0) : uint256(-delta1);

            // TODO: Check the orientation of these reserves, switching them fixed the issue
            uint256 reserveIn = delta0 < 0 ? reserve1 : reserve0;
            uint256 reserveOut = delta0 < 0 ? reserve0 : reserve1;

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
        require(weightOut + weightIn == FixedPoint.ONE, "BAL#308");

        uint256 amountIn = WeightedMath._calcInGivenOut(reserveIn, weightIn, reserveOut, weightOut, amountOut);
        uint256 feeAdjustedAmountIn = (amountIn * tradingFee2) / tradingFee1;

        return feeAdjustedAmountIn;
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
        require(weightOut + weightIn == FixedPoint.ONE, "BAL#308");

        uint256 feeAdjustedAmountIn = (amountIn * tradingFee1) / tradingFee2;

        return WeightedMath._calcOutGivenIn(reserveIn, weightIn, reserveOut, weightOut, feeAdjustedAmountIn);
    }
}
