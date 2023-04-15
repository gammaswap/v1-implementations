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

    /// @dev See {BaseLongStrategy.getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

    function calcDeltasForRatio(uint128[] memory tokensHeld, uint256[] calldata ratio) public virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        (uint128 reserve0, uint128 reserve1,) = ICPMM(s.cfmm).getReserves();
        uint256 factor = 10 ** s.decimals[1];
        uint256 desiredStrikePx = ratio[1] * factor / ratio[0];
        uint256 loanStrikePx = tokensHeld[1] * factor / tokensHeld[0];

        // we're always going to buy
        if(desiredStrikePx > loanStrikePx) { // buy token1, sell token0 (need more token1)
            (tokensHeld[0], tokensHeld[1]) = (tokensHeld[1], tokensHeld[0]);
            deltas = calcDeltasForRatio(desiredStrikePx, reserve1, reserve0, tokensHeld, false);
            // of the two roots, which one makes sense
            // the negative root doesn't make sense
            // the root that requires more than you can purchase doesn't make sense either. So need to transform
            //if(deltas[0] < 0 || deltas[1] > ) deltas[0] = 0;

        } else if(desiredStrikePx < loanStrikePx) { // sell token1, buy token0 (need more token0)
            deltas = calcDeltasForRatio(desiredStrikePx, reserve0, reserve1, tokensHeld, false);
            if(deltas[0] < 0) deltas[0] = 0;
            if(deltas[1] < 0) deltas[1] = 0;
        } else {

        }
        //if(strikePx < loanStrikePx) // sell token1, buy token0
        deltas = calcDeltasForRatio(desiredStrikePx, reserve0, reserve1, tokensHeld, false);
        if(deltas[0] < 0) deltas[0] = 0;
        if(deltas[1] < 0) deltas[1] = 0;/**/
    }


    /// dev See {IGammaPool.getRebalanceDeltas2}.
    // default is selling (-a), so if side is true (sell), switch bIsNeg and remove fee from B in b calc
    // buying should always give us a positive number, if the response is a negative number, then the result is not good
    // result should be
    //  0 index = buying quantity
    //  1 index = selling quantity
    //  we can flip the reserves, tokensHeld, and strikePx to make a buy a sell or a sell a buy
    // side = 0 (false) => buy
    // side = 1 (true)  => sell
    function calcDeltasForRatio(uint256 strikePx, uint128 reserves0, uint128 reserves1, uint128[] memory tokensHeld, bool side) public virtual view returns(int256[] memory deltas) {
        uint256 fee1 = tradingFee1;
        uint256 fee2 = tradingFee2;
        uint256 factor = 10 ** s.decimals[0];
        // must negate
        uint256 a = fee1 * strikePx / fee2;
        // must negate
        bool bIsNeg;
        uint256 b;
        {
            uint256 leftVal;
            {
                uint256 A_times_Phi = tokensHeld[0] * fee1 / fee2;
                uint256 A_hat_times_Phi = side ? reserves0 : reserves0 * fee1 / fee2;
                bIsNeg = A_hat_times_Phi < A_times_Phi;
                leftVal = (bIsNeg ? A_times_Phi - A_hat_times_Phi : A_hat_times_Phi - A_times_Phi) * strikePx / factor;
            }
            uint256 rightVal = side ? (tokensHeld[1] + reserves1) * fee1 / fee2 : (tokensHeld[1] * fee1 / fee2) + reserves1;
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
            uint256 leftVal = tokensHeld[0] * strikePx / factor;
            bool cIsNeg = leftVal < tokensHeld[1];
            uint256 c = (cIsNeg ? tokensHeld[1] - leftVal : leftVal - tokensHeld[1]) * reserves0 * (side ? 1 : fee1 ); // B*A decimals
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
