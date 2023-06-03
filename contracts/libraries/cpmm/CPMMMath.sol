// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/libraries/Math.sol";
import "../../interfaces/math/ICPMMMath.sol";

/// @title Math library for CPMM strategies
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Math library for complex computations for CPMM strategies
contract CPMMMath is ICPMMMath {

    /// @dev See {ICPMMMath-calcDeltasToClose}
    /// @notice how much collateral to trade to have enough to close a position
    /// @notice reserve and collateral have to be of the same token
    /// @notice if > 0 => have to buy token to have exact amount of token to close position
    /// @notice if < 0 => have to sell token to have exact amount of token to close position
    function calcDeltasToClose(uint256 lastCFMMInvariant, uint256 reserve, uint256 collateral, uint256 liquidity)
        external virtual override pure returns(int256 delta) {

        uint256 left = reserve * liquidity;
        uint256 right = collateral * lastCFMMInvariant;
        bool isNeg = right > left;
        uint256 _delta = (isNeg ? right - left : left - right) / (lastCFMMInvariant + liquidity);
        delta = isNeg ? -int256(_delta) : int256(_delta);
    }

    /// @dev See {ICPMMMath-calcDeltasForRatio}
    /// @notice The calculation takes into consideration the market impact the transaction would have
    /// @notice The equation is derived from solving the quadratic root formula taking into account trading fees
    /// @notice default is selling (-a), so if side is true (sell), switch bIsNeg and remove fee from B in b calc
    /// @notice buying should always give us a positive number, if the response is a negative number, then the result is not good
    /// @notice A positive quadratic root means buying, a negative quadratic root means selling
    /// @notice We can flip the reserves, tokensHeld, and ratio to make a buy a sell or a sell a buy
    /// @notice side = 0 (false) => buy, side = 1 (true)  => sell
    function calcDeltasForRatio(uint256 ratio, uint128 reserve0, uint128 reserve1, uint128[] memory tokensHeld,
        uint256 factor, bool side, uint256 fee1, uint256 fee2) external virtual override pure returns(int256[] memory deltas) {
        // must negate
        uint256 a = fee1 * ratio / fee2;
        // must negate
        bool bIsNeg;
        deltas = new int256[](2);
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

    /// @dev See {ICPMMMath-calcDeltasForWithdrawal}.
    function calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves,
        uint256[] calldata ratio, uint256 fee1, uint256 fee2) external virtual override pure returns(int256[] memory deltas) {

        deltas = new int256[](2);
    }
}
