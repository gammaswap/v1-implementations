// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/rebalance/RebalanceStrategy.sol";
import "../../../interfaces/math/ICPMMMath.sol";
import "./CPMMBaseLongStrategy.sol";

/// @title Base Rebalance Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BaseRebalanceStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
abstract contract CPMMBaseRebalanceStrategy is BaseRebalanceStrategy, CPMMBaseLongStrategy {

    error MissingMathLib();
    error CollateralIdGte2();

    /// @return mathLib - contract containing complex mathematical functions
    address immutable public mathLib;

    /// @dev Initializes the contract by setting `mathLib`, `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `origFee`, `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_,
        uint24 origFee_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_,
        uint80 maxApy_) CPMMBaseLongStrategy(ltvThreshold_, maxTotalApy_, blocksPerYear_, origFee_,
        tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {

        if(mathLib_ == address(0)) revert MissingMathLib();
        mathLib = mathLib_;
    }

    /// @dev See {BaseRebalanceStrategy-_calcDeltasToClose}.
    function _calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId)
        internal virtual override view returns(int256[] memory deltas) {

        if(collateralId >= 2) revert CollateralIdGte2();

        deltas = new int256[](2);

        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeWithSelector(ICPMMMath(mathLib).
        calcDeltasToClose.selector, calcInvariant(address(0), reserves), reserves[collateralId],
            tokensHeld[collateralId], liquidity));
        require(success && data.length >= 1);

        deltas[collateralId] = abi.decode(data, (int256));
    }

    /// @dev See {BaseRebalanceStrategy-_calcDeltasForRatio}.
    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio)
        internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);

        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio
        uint256 leftVal = uint256(ratio[1]) * uint256(tokensHeld[0]);
        uint256 rightVal = uint256(ratio[0]) * uint256(tokensHeld[1]);
        if(leftVal > rightVal) { // sell token0, buy token1 (need more token1)
            deltas = _calcDeltasForRatioStaticCall(ratio[1], ratio[0], reserves[1], reserves[0], tokensHeld[1], tokensHeld[0]);
            (deltas[0], deltas[1]) = (0, deltas[0]); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) { // buy token0, sell token1 (need more token0)
            deltas = _calcDeltasForRatioStaticCall(ratio[0], ratio[1], reserves[0], reserves[1], tokensHeld[0], tokensHeld[1]);
            deltas[1] = 0; // 1st quadratic root (index 0) is the only feasible trade
        } // otherwise no trade
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForRatio function
    /// @param ratio0 - numerator of desired ratio to maintain after withdrawal (token0)
    /// @param ratio1 - denominator of desired ratio to maintain after withdrawal (token1)
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @return deltas - quadratic roots (quantities to trade).
    function _calcDeltasForRatioStaticCall(uint256 ratio0, uint256 ratio1, uint128 reserve0, uint128 reserve1,
        uint128 tokensHeld0, uint128 tokensHeld1) internal virtual view returns(int256[] memory deltas) {

        // always buys
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeWithSelector(ICPMMMath(mathLib).
        calcDeltasForRatio.selector, ratio0, ratio1, reserve0, reserve1, tokensHeld0, tokensHeld1, tradingFee1, tradingFee2));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }

    /// @dev See {BaseRebalanceStrategy-_calcDeltasForWithdrawal}.
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves,
        uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {

        if(amounts[0] > 0) {
            deltas = _calcDeltasForWithdrawalStaticCall(amounts[0], ratio[0], ratio[1], reserves[0], reserves[1],
                tokensHeld[0], tokensHeld[1]);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 2nd root (index 1) is the only feasible trade
        } else if(amounts[1] > 0){
            deltas = _calcDeltasForWithdrawalStaticCall(amounts[1],  ratio[1], ratio[0], reserves[1], reserves[0],
                tokensHeld[1], tokensHeld[0]);
            deltas[0] = 0; // 2nd root (index 1) is the only feasible trade
        } // otherwise no trade
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForWithdrawal function
    /// @param amount - amount of token0 requesting to withdraw
    /// @param ratio0 - numerator of desired ratio to maintain after withdrawal (token0)
    /// @param ratio1 - denominator of desired ratio to maintain after withdrawal (token1)
    /// @param reserve0 - reserve quantities of token0 in CFMM
    /// @param reserve1 - reserve quantities of token1 in CFMM
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @return deltas - quantities of reserve tokens to rebalance after withdrawal.
    function _calcDeltasForWithdrawalStaticCall(uint128 amount, uint256 ratio0, uint256 ratio1,uint128 reserve0,
        uint128 reserve1, uint128 tokensHeld0, uint128 tokensHeld1) internal virtual view returns(int256[] memory deltas) {

        // always buys
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeWithSelector(ICPMMMath(mathLib).
        calcDeltasForWithdrawal.selector, amount, ratio0, ratio1, reserve0, reserve1, tokensHeld0, tokensHeld1,
            tradingFee1, tradingFee2));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }
}
