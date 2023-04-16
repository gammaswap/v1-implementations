// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/LongStrategy.sol";
import "./CPMMBaseLongStrategy.sol";

/// @title Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LongStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMLongStrategy is CPMMBaseLongStrategy, LongStrategy {

    /// @dev Initializes the contract by setting `_ltvThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_originationFee`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
    constructor(uint16 _ltvThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint24 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseLongStrategy(_ltvThreshold, _maxTotalApy, _blocksPerYear, _originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    /// @dev See {BaseLongStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

    /// @dev See {ILongStrategy-calcDeltasToClose}.
    function calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasToClose(tokensHeld, reserves, liquidity, collateralId);
    }

    /// @dev See {ILongStrategy-calcDeltasForRatio}.
    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasForRatio(tokensHeld, reserves, ratio);
    }

    /// @dev See {LongStrategy-_calcDeltasForRatio}.
    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) public virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        (uint128 reserve0, uint128 reserve1) = (reserves[0], reserves[1]);
        uint256 factor = 10 ** s.decimals[0];
        uint256 desiredRatio = ratio[1] * factor / ratio[0];
        uint256 loanRatio = tokensHeld[1] * factor / tokensHeld[0];

        // we're always going to buy, therefore when desiredRatio > loanRatio, invert reserves, collaterals, and desiredRatio
        if(desiredRatio > loanRatio) { // sell token0, buy token1 (need more token1)
            (tokensHeld[0], tokensHeld[1]) = (tokensHeld[1], tokensHeld[0]); // invert collateral
            desiredRatio = factor * (10 ** s.decimals[1]) / desiredRatio; // invert price
            deltas = calcDeltasForRatio(desiredRatio, reserve1, reserve0, tokensHeld, false); // always buying
            (deltas[0], deltas[1]) = (0, deltas[0]); // revert results
        } else if(desiredRatio < loanRatio) { // buy token0, sell token1 (need more token0)
            deltas = calcDeltasForRatio(desiredRatio, reserve0, reserve1, tokensHeld, false); // always buying
            deltas[1] = 0;
        } else {
            (deltas[0], deltas[1]) = (0, 0); // no trade
        }
    }

    /// @dev See calculate quantities to trade to rebalance collateral (`tokensHeld`) to the desired `ratio`
    /// @notice The calculation takes into consideration the market impact the transaction would have
    /// @notice The eqution is derived from solving the quadratic root formula taking into account trading fees
    /// @notice default is selling (-a), so if side is true (sell), switch bIsNeg and remove fee from B in b calc
    /// @notice buying should always give us a positive number, if the response is a negative number, then the result is not good
    /// @notice A positive quadratic root means buying, a negative quadratic root means selling
    /// @notice We can flip the reserves, tokensHeld, and ratio to make a buy a sell or a sell a buy
    /// @notice side = 0 (false) => buy, side = 1 (true)  => sell
    /// @param ratio - desired ratio we wish collateral (`tokensHeld`) to have
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param tokensHeld - collateral to rebalance
    /// @param side - side of token to rebalance
    /// @return deltas - quadratic roots (quantities to trade). The first quadratic root (index 0) is the only feasible trade
    function calcDeltasForRatio(uint256 ratio, uint128 reserve0, uint128 reserve1, uint128[] memory tokensHeld, bool side) public virtual view returns(int256[] memory deltas) {
        uint256 fee1 = tradingFee1;
        uint256 fee2 = tradingFee2;
        uint256 factor = 10 ** s.decimals[0];
        // must negate
        uint256 a = fee1 * ratio / fee2;
        // must negate
        bool bIsNeg;
        uint256 b;
        {
            uint256 leftVal;
            {
                uint256 A_times_Phi = tokensHeld[0] * fee1 / fee2;
                uint256 A_hat_times_Phi = side ? reserve0 : reserve0 * fee1 / fee2;
                bIsNeg = A_hat_times_Phi < A_times_Phi;
                leftVal = (bIsNeg ? A_times_Phi - A_hat_times_Phi : A_hat_times_Phi - A_times_Phi) * ratio / factor;
            }
            uint256 rightVal = side ? (tokensHeld[1] + reserve1) * fee1 / fee2 : (tokensHeld[1] * fee1 / fee2) + reserve1;
            if(bIsNeg) { // leftVal < 0
                bIsNeg = leftVal < rightVal;
                if(bIsNeg) {
                    b = rightVal - leftVal;
                } else {
                    b = leftVal - rightVal;
                }
            } else {
                b = leftVal + rightVal;
                bIsNeg = true;
            }
            bIsNeg = side == false ? !bIsNeg : bIsNeg;
        }

        uint256 det;
        {
            uint256 leftVal = tokensHeld[0] * ratio / factor;
            bool cIsNeg = leftVal < tokensHeld[1];
            uint256 c = (cIsNeg ? tokensHeld[1] - leftVal : leftVal - tokensHeld[1]) * reserve0 * (side ? 1 : fee1 ); // B*A decimals
            c = side ? c : c / fee2;
            uint256 ac4 = 4 * c * a / factor;
            det = Math.sqrt(!cIsNeg ? b**2 + ac4 : b**2 - ac4); // should check here that won't get an imaginary number
        }

        // remember that a is always negative
        // root = (-b +/- det)/(2a)
        if(bIsNeg) { // b < 0
            // plus version
            // (b + det)/-2a = -(b + det)/2a
            // this is always negative
            deltas[0] = -int256((b + det) * factor / (2*a));

            // minus version
            // (b - det)/-2a = (det-b)/2a
            if(det > b) {
                // x2 is positive
                deltas[1] = int256((det - b) * factor / (2*a));
            } else {
                // x2 is negative
                deltas[1]= -int256((b - det) * factor / (2*a));
            }
        } else { // b > 0
            // plus version
            // (-b + det)/-2a = (b - det)/2a
            if(b > det) {
                //  x1 is positive
                deltas[0] = int256((b - det) * factor / (2*a));
            } else {
                //  x1 is negative
                deltas[0] = -int256((det - b) * factor / (2*a));
            }

            // minus version
            // (-b - det)/-2a = (b+det)/2a
            deltas[1] = int256((b + det) * factor / (2*a));
        }
    }
}
