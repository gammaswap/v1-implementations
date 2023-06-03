// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/LongStrategy.sol";
import "./CPMMBaseLongStrategy.sol";

/// @title Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LongStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMLongStrategy is CPMMBaseLongStrategy, LongStrategy {

    error MissingMathLib();

    /// @dev Initializes the contract by setting `mathLib`, `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `origFee`, `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_,
        uint24 origFee_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_,
        uint80 maxApy_) CPMMBaseLongStrategy(mathLib_, ltvThreshold_, maxTotalApy_, blocksPerYear_, origFee_,
        tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {

        if(mathLib_ == address(0)) revert MissingMathLib();
    }

    /// @dev See {BaseLongStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

    /// @dev See {ILongStrategy-calcDeltasToClose}.
    function calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity,
        uint256 collateralId) external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasToClose(tokensHeld, reserves, liquidity, collateralId);
    }

    /// @dev See {ILongStrategy-calcDeltasForRatio}.
    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio)
        external virtual override view returns(int256[] memory deltas) {
        deltas = _calcDeltasForRatio(tokensHeld, reserves, ratio);
    }

    /// @dev See {LongStrategy-_calcDeltasForRatio}.
    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio)
        internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        (uint128 reserve0, uint128 reserve1) = (reserves[0], reserves[1]);
        uint256 factor0 = 10 ** s.decimals[0];
        uint256 desiredRatio = ratio[1] * factor0 / ratio[0];
        uint256 loanRatio = tokensHeld[1] * factor0 / tokensHeld[0];

        // we only buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio
        if(desiredRatio > loanRatio) { // sell token0, buy token1 (need more token1)
            (tokensHeld[0], tokensHeld[1]) = (tokensHeld[1], tokensHeld[0]); // invert collateral
            uint256 factor1 = 10 ** s.decimals[1];
            desiredRatio = factor0 * factor1 / desiredRatio; // invert price
            deltas = _calcDeltasForRatioStaticCall(desiredRatio, reserve1, reserve0, tokensHeld, factor1);
            (deltas[0], deltas[1]) = (0, deltas[0]); // revert results, 1st root (index 0) is the only feasible trade
        } else if(desiredRatio < loanRatio) { // buy token0, sell token1 (need more token0)
            deltas = _calcDeltasForRatioStaticCall(desiredRatio, reserve0, reserve1, tokensHeld, factor0);
            deltas[1] = 0; // 1st quadratic root (index 0) is the only feasible trade
        } // otherwise no trade
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForRatio function
    /// @param ratio - desired ratio we wish collateral (`tokensHeld`) to have
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param tokensHeld - collateral to rebalance
    /// @param factor - decimals expansion number of first token (e.g. 10^(token0's decimals))
    /// @return deltas - quadratic roots (quantities to trade).
    function _calcDeltasForRatioStaticCall(uint256 ratio, uint128 reserve0, uint128 reserve1,
        uint128[] memory tokensHeld, uint256 factor) internal virtual view returns(int256[] memory deltas) {

        // side = false => always buying
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeWithSelector(ICPMMMath(mathLib).
            calcDeltasForRatio.selector, ratio, reserve0, reserve1, tokensHeld, factor, false, tradingFee1, tradingFee2));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }

    /// @dev See {LongStrategy-_calcDeltasForWithdrawal}.
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves,
        uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {

        if(amounts[0] > 0) {
            deltas = _calcDeltasForWithdrawalStaticCall(amounts[0], tokensHeld[0], tokensHeld[1], reserves[0], reserves[1],
                ratio[0], ratio[1]);
            (deltas[0], deltas[1]) = (deltas[1], 0); // revert results, 2nd root (index 1) is the only feasible trade
        } else if(amounts[1] > 0){
            deltas = _calcDeltasForWithdrawalStaticCall(amounts[1], tokensHeld[1], tokensHeld[0], reserves[1], reserves[0],
                ratio[1], ratio[0]);
            deltas[0] = 0; // 2nd root (index 1) is the only feasible trade
        } // otherwise no trade
    }

    /// @dev Function to perform static call to MathLib.calcDeltasForWithdrawal function
    /// @param amount - amount of token0 requesting to withdraw
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantities of token0 in CFMM
    /// @param reserve1 - reserve quantities of token1 in CFMM
    /// @param ratio0 - numerator of desired ratio to maintain after withdrawal (token0)
    /// @param ratio1 - denominator of desired ratio to maintain after withdrawal (token1)
    /// @return deltas - quantities of reserve tokens to rebalance after withdrawal.
    function _calcDeltasForWithdrawalStaticCall(uint128 amount, uint128 tokensHeld0, uint128 tokensHeld1, uint128 reserve0,
        uint128 reserve1, uint256 ratio0, uint256 ratio1) internal virtual view returns(int256[] memory deltas) {

        // side = false => always buying
        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeWithSelector(ICPMMMath(mathLib).
            calcDeltasForWithdrawal.selector, amount, tokensHeld0, tokensHeld1, reserve0, reserve1, ratio0, ratio1,
            tradingFee1, tradingFee2));
        require(success && data.length >= 1);

        deltas = abi.decode(data, (int256[]));
    }
}
