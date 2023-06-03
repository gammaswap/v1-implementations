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
            deltas = ICPMMMath(mathLib).calcDeltasForRatio(desiredRatio, reserve1, reserve0, tokensHeld, factor1, false,
                tradingFee1, tradingFee2); // always buying
            (deltas[0], deltas[1]) = (0, deltas[0]); // revert results
        } else if(desiredRatio < loanRatio) { // buy token0, sell token1 (need more token0)
            deltas = ICPMMMath(mathLib).calcDeltasForRatio(desiredRatio, reserve0, reserve1, tokensHeld, factor0, false,
                tradingFee1, tradingFee2); // always buying
            deltas[1] = 0;
        } else {
            (deltas[0], deltas[1]) = (0, 0); // no trade
        }
    }

    /// @dev See {LongStrategy-_calcDeltasForWithdrawal}.
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves,
        uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {

        deltas = ICPMMMath(mathLib).calcDeltasForWithdrawal(amounts, tokensHeld, reserves, ratio, tradingFee1, tradingFee2);
    }
}
