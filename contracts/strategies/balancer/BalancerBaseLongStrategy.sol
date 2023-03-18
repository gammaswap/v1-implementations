// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@gammaswap/v1-core/contracts/strategies/BaseLongStrategy.sol";
import "../../libraries/weighted/FixedPoint.sol";
import "../../libraries/weighted/WeightedMath.sol";
import "../../libraries/weighted/InputHelpers.sol";
import "./BalancerBaseStrategy.sol";

/// @title Base Long Strategy concrete implementation contract for Balancer Weighted Pools
/// @notice Common functions used by all concrete strategy implementations for Balancer Weighted Pools that need access to loans
/// @dev This implementation was specifically designed to work with Balancer Weighted Pools
abstract contract BalancerBaseLongStrategy is BaseLongStrategy, BalancerBaseStrategy {
    error BadDelta();
    error BadOutAmts();
    error ZeroReserves();
    error BAL308();

    /// @return origFee Origination fee charged to every new loan that is issued.
    uint24 immutable public origFee;

    /// @return LTV_THRESHOLD Maximum Loan-To-Value ratio acceptable before a loan is eligible for liquidation.
    uint16 immutable public LTV_THRESHOLD;

    /// @return Returns the minimum liquidity borrowed amount.
    uint256 constant public MIN_BORROW = 1e3;

    /// @dev Initializes the contract by setting `_ltvThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_originationFee`, `_baseRate`, `_factor`, `_maxApy`, and `_weight0`
    constructor(uint16 _ltvThreshold,  uint256 _maxTotalApy, uint256 _blocksPerYear, uint24 _originationFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0)
        BalancerBaseStrategy(_maxTotalApy, _blocksPerYear, _baseRate, _factor, _maxApy, _weight0) {
        LTV_THRESHOLD = _ltvThreshold;
        origFee = _originationFee;
    }

    /// @dev See {BaseLongStrategy.minBorrow}.
    function minBorrow() internal virtual override view returns(uint256) {
        return MIN_BORROW;
    }

    /// @dev See {BaseLongStrategy.ltvThreshold}.
    function ltvThreshold() internal virtual override view returns(uint16) {
        return LTV_THRESHOLD;
    }

    /// @dev See {BaseLongStrategy.originationFee}.
    function originationFee() internal virtual override view returns(uint24) {
        return origFee;
    }

    /// @dev See {BaseLongStrategy.calcTokensToRepay}.
    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;

        // This has been unmodified from the Uniswap implementation
        amounts[0] = (liquidity * s.CFMM_RESERVES[0] / lastCFMMInvariant);
        amounts[1] = (liquidity * s.CFMM_RESERVES[1] / lastCFMMInvariant);
    }

    /// @dev Empty implementation for Balancer. See {BaseLongStrategy.beforeRepay} for a discussion on the purpose of this function.
    function beforeRepay(LibStorage.Loan storage, uint256[] memory) internal virtual override {
    }

    /// @dev See {BaseLongStrategy.swapTokens}.
    function swapTokens(LibStorage.Loan storage, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address assetIn;
        address assetOut;
        uint256 amountIn;
        uint256 amountOut;
        address[] memory tokens = s.tokens;

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
            revert BadOutAmts();
        }

        IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
            poolId: getPoolId(),
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

        IVault(getVault()).swap(singleSwap, fundManagement, 0, block.timestamp);
    }

    /// @dev Check that there's enough collateral (`amount`) in the pool and the loan. If not revert
    /// @param amount - amount to check
    /// @param balance - total pool balance
    /// @param collateral - total collateral in loan
    /// @return _amount - same as `amount` if transaction did not revert
    function checkAvailableCollateral(uint256 amount, uint256 balance, uint256 collateral) internal virtual pure returns(uint256){
        if(amount > balance) { // Check enough in pool's accounted balance
            revert NotEnoughBalance();
        }
        if(amount > collateral) { // Check enough collateral in loan
            revert NotEnoughCollateral();
        }
        return amount;
    }

    /// @dev See {BaseLongStrategy.beforeSwapTokens}.
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);

        // NOTE: inAmts is the quantity of tokens going INTO the GammaPool
        // outAmts is the quantity of tokens going OUT OF the GammaPool

        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = calcInAndOutAmounts(s.CFMM_RESERVES, deltas);

        outAmts[0] = outAmts[0] > 0 ? checkAvailableCollateral(outAmts[0], s.TOKEN_BALANCE[0], _loan.tokensHeld[0]) : 0;
        outAmts[1] = outAmts[1] > 0 ? checkAvailableCollateral(outAmts[1], s.TOKEN_BALANCE[1], _loan.tokensHeld[1]) : 0;
    }

    /// @dev Calculates the expected bought and sold amounts corresponding to a change in collateral given by delta.
    ///     This calculation depends on the reserves existing in the Balancer pool.
    /// @param reserves The amount of reserve tokens in the Balancer pool
    /// @param deltas The desired amount of collateral tokens from the loan to swap (> 0 buy, < 0 sell, 0 ignore)
    /// @return inAmt0 The expected amount of token0 to receive from the Balancer pool (corresponding to a buy)
    /// @return inAmt1 The expected amount of token1 to receive from the Balancer pool (corresponding to a buy)
    /// @return outAmt0 The expected amount of token0 to send to the Balancer pool (corresponding to a sell)
    /// @return outAmt1 The expected amount of token1 to send to the Balancer pool (corresponding to a sell)
    function calcInAndOutAmounts(uint128[] memory reserves, int256[] calldata deltas)
        internal view returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        if(!((deltas[0] != 0 && deltas[1] == 0) || (deltas[0] == 0 && deltas[1] != 0))) {
            revert BadDelta();
        }

        if(reserves[0] == 0 || reserves[1] == 0) {
            revert ZeroReserves();
        }

        uint256[] memory weights = getWeights();
        uint256[] memory scalingFactors = getScalingFactors();

        if (deltas[0] > 0 || deltas[1] > 0) {
            // If the delta is positive, then we are buying a token from the Balancer pool
            if (deltas[0] > 0) {
                // Then the first token corresponds to the token that the GammaPool is getting from the Balancer pool
                inAmt0 = uint256(deltas[0]);
                inAmt1 = 0;
                outAmt0 = 0;
                outAmt1 = getAmountIn(uint256(deltas[0]), reserves, weights, scalingFactors, 0, 1);
            } else {
                inAmt0 = 0;
                inAmt1 = uint256(deltas[1]);
                outAmt0 = getAmountIn(uint256(deltas[1]), reserves, weights, scalingFactors, 1, 0);
                outAmt1 = 0;
            }
        } else {
            // If the delta is negative, then we are selling a token to the Balancer pool
            if (deltas[0] < 0) {
                inAmt0 = 0;
                inAmt1 = getAmountOut(uint256(-deltas[0]), reserves, weights, scalingFactors, 1, 0);
                outAmt0 = uint256(-deltas[0]);
                outAmt1 = 0;
            } else {
                inAmt0 = getAmountOut(uint256(-deltas[1]), reserves, weights, scalingFactors, 0, 1);
                inAmt1 = 0;
                outAmt0 = 0;
                outAmt1 = uint256(-deltas[1]);
            }
        }
    }

    /// @dev Calculates the amountIn amount required for an exact amountOut value according to the Balancer invariant formula.
    /// @param amountOut - The amount of token removed from the pool during the swap.
    /// @param reserves - The pool reserves for the token exiting the pool on the swap.
    /// @param weights - The normalised weight of the token exiting the pool on the swap.
    /// @param scalingFactors - The pool's scaling factors (10 ** (18 - decimals))
    /// @param outIdx - Index of reserves, weights, decimals array that represent token leaving GammaPool
    /// @param inIdx - Index of reserves, weights, decimals array that represent token coming into GammaPool
    /// @return amountIn - The normalised weight of the token entering the pool on the swap.
    function getAmountIn(uint256 amountOut, uint128[] memory reserves, uint256[] memory weights, uint256[] memory scalingFactors, uint256 outIdx, uint256 inIdx) internal view returns (uint256) {
        // Revert if the sum of normalised weights is not equal to 1
        if(weights[outIdx] + weights[inIdx] != FixedPoint.ONE) {
            revert BAL308();
        }

        // Upscale the input data to account for decimals
        uint256 rescaledReserveOut = InputHelpers.upscale(reserves[outIdx], scalingFactors[outIdx]);
        uint256 rescaledReserveIn = InputHelpers.upscale(reserves[inIdx], scalingFactors[inIdx]);
        uint256 rescaledAmountOut = InputHelpers.upscale(amountOut, scalingFactors[outIdx]);

        uint256 amountIn = WeightedMath._calcInGivenOut(rescaledReserveIn, weights[inIdx], rescaledReserveOut, weights[outIdx], rescaledAmountOut);

        // Downscale the amountIn to account for decimals
        uint256 downscaledAmountIn = InputHelpers.downscale(amountIn, scalingFactors[inIdx]);

        uint256 feeAdjustedAmountIn = (downscaledAmountIn * 1e18) / (1e18 - getSwapFeePercentage(s.cfmm));

        return feeAdjustedAmountIn;
    }

    /// @dev Calculates the amountOut swap amount given for an exact amountIn value according to the Balancer invariant formula.
    /// @param amountIn The amount of token swapped into the pool.
    /// @param reserves - The pool reserves for the token exiting the pool on the swap.
    /// @param weights - The normalised weight of the token exiting the pool on the swap.
    /// @param scalingFactors - The pool's scaling factors (10 ** (18 - decimals))
    /// @param outIdx - Index of reserves, weights, decimals array that represent token leaving GammaPool
    /// @param inIdx - Index of reserves, weights, decimals array that represent token coming into GammaPool
    /// @return amountOut - The amount of token removed from the pool during the swap.
    function getAmountOut(uint256 amountIn, uint128[] memory reserves, uint256[] memory weights, uint256[] memory scalingFactors, uint256 outIdx, uint256 inIdx) internal view returns (uint256) {
        // Revert if the sum of normalised weights is not equal to 1
        if(weights[outIdx] + weights[inIdx] != FixedPoint.ONE) {
            revert BAL308();
        }

        uint256 rescaledReserveOut = InputHelpers.upscale(reserves[outIdx], scalingFactors[outIdx]);
        uint256 rescaledReserveIn = InputHelpers.upscale(reserves[inIdx], scalingFactors[inIdx]);
        uint256 rescaledAmountIn = InputHelpers.upscale(amountIn, scalingFactors[inIdx]);

        uint256 feeAdjustedAmountIn = (rescaledAmountIn * (1e18 - getSwapFeePercentage(s.cfmm))) / 1e18;

        uint256 amountOut = WeightedMath._calcOutGivenIn(rescaledReserveIn, weights[inIdx], rescaledReserveOut, weights[outIdx], feeAdjustedAmountIn);

        // Downscale the amountOut to account for decimals
        return InputHelpers.downscale(amountOut, scalingFactors[outIdx]);
    }
}
