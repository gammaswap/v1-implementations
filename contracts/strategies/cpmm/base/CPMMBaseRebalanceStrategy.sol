// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

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
    error LowPostTradeCollateral();

    /// @return mathLib - contract containing complex mathematical functions
    address immutable public mathLib;

    /// @dev Initializes the contract by setting `mathLib`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 tradingFee1_, address feeSource_,
        uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseLongStrategy(maxTotalApy_,
        blocksPerYear_, tradingFee1_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {

        if(mathLib_ == address(0)) revert MissingMathLib();
        mathLib = mathLib_;
    }

    /// @dev See {BaseRebalanceStrategy-_calcDeltasToCloseSetRatio}.
    function _calcDeltasToCloseSetRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256[] memory ratio) internal override virtual view returns(int256[] memory deltas) {
        deltas = new int256[](2);

        uint8 invDecimals = (s.decimals[0] + s.decimals[1])/2;
        uint256 factor = 10**invDecimals;
        uint256 leftVal = uint256(ratio[1]) * factor;
        uint256 rightVal = uint256(ratio[0]) * factor;
        if(leftVal > rightVal) {
            deltas = _calcDeltasToCloseSetRatioStaticCall(liquidity, tokensHeld[0], tokensHeld[1], reserves[0], reserves[1], ratio[0], ratio[1], invDecimals);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) {
            deltas = _calcDeltasToCloseSetRatioStaticCall(liquidity, tokensHeld[1], tokensHeld[0], reserves[1], reserves[0], ratio[1], ratio[0], invDecimals);
            (deltas[0], deltas[1]) = (0, deltas[1]); // swap result, 1st root (index 0) is the only feasible trade
        }
    }

    /// @dev See {BaseRebalanceStrategy-_calcCollateralPostTrade}.
    function _calcCollateralPostTrade(int256[] memory deltas, uint128[] memory tokensHeld, uint128[] memory reserves) internal override virtual view returns(uint256 collateral) {
        if(deltas[0] > 0) {
            collateral = _calcCollateralPostTradeStaticCall(calcInvariant(address(0), tokensHeld), uint256(deltas[0]), tokensHeld[0], tokensHeld[1], reserves[0], reserves[1]);
        } else if(deltas[1] > 0) {
            collateral = _calcCollateralPostTradeStaticCall(calcInvariant(address(0), tokensHeld), uint256(deltas[1]), tokensHeld[1], tokensHeld[0], reserves[1], reserves[0]);
        } else {
            collateral = calcInvariant(address(0), tokensHeld);
        }
    }

    /// @dev See {BaseRebalanceStrategy-_calcDeltasForMaxLP}.
    function _calcDeltasForMaxLP(uint128[] memory tokensHeld, uint128[] memory reserves) internal override virtual view returns(int256[] memory deltas) {
        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio
        deltas = new int256[](2);

        uint256 leftVal = uint256(reserves[0]) * uint256(tokensHeld[1]);
        uint256 rightVal = uint256(reserves[1]) * uint256(tokensHeld[0]);

        if(leftVal > rightVal) {
            deltas = _calcDeltasForMaxLPStaticCall(tokensHeld[0], tokensHeld[1], reserves[0], reserves[1], s.decimals[0]);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) {
            deltas = _calcDeltasForMaxLPStaticCall(tokensHeld[1], tokensHeld[0], reserves[1], reserves[0], s.decimals[1]);
            (deltas[0], deltas[1]) = (0, deltas[1]); // swap result, 1st root (index 0) is the only feasible trade
        }
    }

    /// @dev See {BaseRebalanceStrategy-_calcDeltasToClose}.
    function _calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId)
        internal virtual override view returns(int256[] memory deltas) {

        if(collateralId >= 2) revert CollateralIdGte2();

        deltas = new int256[](2);

        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeCall(ICPMMMath.calcDeltasToClose,
            (liquidity, calcInvariant(address(0), reserves), tokensHeld[collateralId], reserves[collateralId])));
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
            deltas = _calcDeltasForRatioStaticCall(ratio[1], ratio[0], tokensHeld[1], tokensHeld[0], reserves[1], reserves[0]);
            (deltas[0], deltas[1]) = (0, deltas[0]); // swap result, 1st root (index 0) is the only feasible trade
        } else if(leftVal < rightVal) { // buy token0, sell token1 (need more token0)
            deltas = _calcDeltasForRatioStaticCall(ratio[0], ratio[1], tokensHeld[0], tokensHeld[1], reserves[0], reserves[1]);
            deltas[1] = 0; // 1st quadratic root (index 0) is the only feasible trade
        } // otherwise no trade
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForRatio function
    /// @param liquidity - liquidity debt that needs to be repaid after rebalancing loan's collateral quantities
    /// @param ratio0 - ratio parameter of token0
    /// @param ratio1 - ratio parameter of token1
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param decimals0 - decimals of token0
    /// @return deltas - quadratic roots (quantities to trade).
    function _calcDeltasToCloseSetRatioStaticCall(uint256 liquidity, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1, uint256 ratio0, uint256 ratio1, uint8 decimals0) internal virtual view returns(int256[] memory deltas) {

        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeCall(ICPMMMath.
            calcDeltasToCloseSetRatio, (liquidity, ratio0, ratio1, tokensHeld0, tokensHeld1, reserve0, reserve1, decimals0)));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }

    /// @dev Calculate value of collateral in terms of liquidity invariant after transaction
    /// @param preCollateral - pre rebalance collateral
    /// @param delta - quantity of token0 to purchase from CFMM
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @return collateral - collateral after transaction in terms of liquidity invariant
    function _calcCollateralPostTradeStaticCall(uint256 preCollateral, uint256 delta, uint128 tokensHeld0, uint128 tokensHeld1, uint256 reserve0, uint256 reserve1) internal virtual view returns(uint256 collateral) {
        uint16 _tradingFee1 = getTradingFee1();
        uint256 minCollateral = preCollateral * (_tradingFee1 + (tradingFee2 - _tradingFee1) / 2)/ tradingFee2;

        // always buys
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeCall(ICPMMMath.
            calcCollateralPostTrade, (delta, tokensHeld0, tokensHeld1, reserve0, reserve1, _tradingFee1, tradingFee2)));
        require(success && data.length >= 1);

        collateral = abi.decode(data, (uint256));

        if(collateral < minCollateral) revert LowPostTradeCollateral();
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForRatio function
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param decimals0 - decimals of token0
    /// @return deltas - quadratic roots (quantities to trade).
    function _calcDeltasForMaxLPStaticCall(uint128 tokensHeld0, uint128 tokensHeld1, uint128 reserve0, uint128 reserve1,
        uint8 decimals0) internal virtual view returns(int256[] memory deltas) {

        // always buys
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeCall(ICPMMMath.
            calcDeltasForMaxLP, (tokensHeld0, tokensHeld1, reserve0, reserve1, getTradingFee1(), tradingFee2, decimals0)));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForRatio function
    /// @param ratio0 - numerator of desired ratio to maintain after withdrawal (token0)
    /// @param ratio1 - denominator of desired ratio to maintain after withdrawal (token1)
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @return deltas - quadratic roots (quantities to trade).
    function _calcDeltasForRatioStaticCall(uint256 ratio0, uint256 ratio1, uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1) internal virtual view returns(int256[] memory deltas) {

        // always buys
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeCall(ICPMMMath.calcDeltasForRatio,
            (ratio0, ratio1, tokensHeld0, tokensHeld1, reserve0, reserve1, getTradingFee1(), tradingFee2)));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }

    /// @dev See {BaseRebalanceStrategy-_calcDeltasForWithdrawal}.
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves,
        uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {

        if(amounts[0] > 0) {
            deltas = _calcDeltasForWithdrawalStaticCall(amounts[0], ratio[0], ratio[1], tokensHeld[0], tokensHeld[1], reserves[0], reserves[1]);
            (deltas[0], deltas[1]) = (deltas[1], 0); // swap result, 2nd root (index 1) is the only feasible trade
        } else if(amounts[1] > 0){
            deltas = _calcDeltasForWithdrawalStaticCall(amounts[1], ratio[1], ratio[0], tokensHeld[1], tokensHeld[0], reserves[1], reserves[0]);
            deltas[0] = 0; // 2nd root (index 1) is the only feasible trade
        } // otherwise no trade
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForWithdrawal function
    /// @param amount - amount of token0 requesting to withdraw
    /// @param ratio0 - numerator of desired ratio to maintain after withdrawal (token0)
    /// @param ratio1 - denominator of desired ratio to maintain after withdrawal (token1)
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantities of token0 in CFMM
    /// @param reserve1 - reserve quantities of token1 in CFMM
    /// @return deltas - quantities of reserve tokens to rebalance after withdrawal.
    function _calcDeltasForWithdrawalStaticCall(uint128 amount, uint256 ratio0, uint256 ratio1,uint128 tokensHeld0, uint128 tokensHeld1,
        uint128 reserve0, uint128 reserve1) internal virtual view returns(int256[] memory deltas) {

        // always buys
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeCall(ICPMMMath.calcDeltasForWithdrawal,
            (amount, ratio0, ratio1, tokensHeld0, tokensHeld1, reserve0, reserve1, getTradingFee1(), tradingFee2)));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }
}
