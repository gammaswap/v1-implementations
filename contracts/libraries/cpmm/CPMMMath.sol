// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/libraries/Math.sol";
import "../../interfaces/math/ICPMMMath.sol";

/// @title Math library for CPMM strategies
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Math library for complex computations for CPMM strategies
contract CPMMMath is ICPMMMath {

    /// @dev See {ICPMMMath-calcDeltasForRatio}
    /// @notice The calculation takes into consideration the market impact the transaction would have
    /// @notice The equation is derived from solving the quadratic root formula taking into account trading fees
    /// @notice This equation should always result in a recommendation to purchase token0 (a positive number)
    /// @notice Since a negative quadratic root means selling, if the result is negative, then the result is wrong
    /// @notice We can flip the reserves, tokensHeld, and ratio to turn a purchase of token0 into a sale of token0
    function calcDeltasForMaxLP(uint256 reserve0, uint256 reserve1, uint256 tokensHeld0,
        uint256 tokensHeld1, uint256 fee1, uint256 fee2) external virtual override pure returns(int256[] memory deltas) {
        //TODO: Formula goes here
    }

    /// @dev See {ICPMMMath-calcDeltasToCloseSetRatio}
    /// @notice The calculation takes into consideration the market impact the transaction would have
    /// @notice The equation is derived from solving the quadratic root formula taking into a   ccount trading fees
    /// @notice This equation should always result in a recommendation to purchase token0 (a positive number)
    /// @notice Since a negative quadratic root means selling, if the result is negative, then the result is wrong
    /// @notice We can flip the reserves, tokensHeld, and ratio to turn a purchase of token0 into a sale of token0
    function calcDeltasToCloseSetRatio(uint128 liquidity, uint256 lastCFMMInvariant, uint256 reserve0, uint256 reserve1, uint256 tokensHeld0,
        uint256 tokensHeld1, uint256 ratio0, uint256 ratio1) external view returns(int256[] memory deltas) {
        //TODO: Formula goes here
        // phi = liquidity / lastCFMMInvariant
        //     = L / L_hat
        //
        // a = P * (1 + phi)
        //   = (ratio1 / ratio0) + (ratio1 * liquidity) / (ratio0 * lastCFMMInvariant)
        uint256 a;

        // b = -(P * (A_hat * (2 * phi + 1) - A) + B + B_hat)
        //   = -(P * (A_hat * 2 * phi + A_hat - A) + B + B_hat)
        //   = -(P * A_hat * 2 * phi + P * A_hat - P * A + B + B_hat)
        //   = -(ratio1 * A_hat * 2 * liquidity / (ratio0 * lastCFMMInvariant) - ratio1 * A_hat / ratio0 - ratio1 * A / ratio0 + B + B_hat)
        uint256 b;

        // c = A_hat * [B - P * (A - A * phi)] - L * L_hat
        //   = A_hat * [B - P * A - P * A * phi] - L * L_hat
        //   = A_hat * B - A_hat * P * A - A_hat * P * A * phi - L * L_hat
        //   = A_hat * B - A_hat * ratio1 * A / ratio0 - A_hat * ratio1 * A * L / (ratio0 * L_hat) - L * L_hat
        uint256 c;

    }

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
    /// @notice This equation should always result in a recommendation to purchase token0 (a positive number)
    /// @notice Since a negative quadratic root means selling, if the result is negative, then the result is wrong
    /// @notice We can flip the reserves, tokensHeld, and ratio to turn a purchase of token0 into a sale of token0
    function calcDeltasForRatio(uint256 ratio0, uint256 ratio1, uint256 reserve0, uint256 reserve1, uint256 tokensHeld0,
        uint256 tokensHeld1, uint256 fee1, uint256 fee2) external virtual override view returns(int256[] memory deltas) {
        // a = -P*fee
        //   = -ratio1 * fee1 / (ratio0 * fee2)
        // must negate
        bool bIsNeg;
        uint256 b;
        {
            // b = (A_hat - A)*P*fee + (B*fee + B_hat)
            //   = (A_hat - A)*(ratio1/ratio0)*(fee1/fee2) + (B*fee1/fee2 + B_hat)
            //   = [(A_hat*ratio1*fee1 - A*ratio1*fee1) / ratio0 + B*fee1] / fee2 + B_hat
            uint256 leftVal;
            {
                uint256 A_hat_x_ratio1_x_fee1 = reserve0 * ratio1 * fee1;
                uint256 A_x_ratio1_x_fee1 = tokensHeld0 * ratio1 * fee1;
                bIsNeg = A_hat_x_ratio1_x_fee1 < A_x_ratio1_x_fee1;
                leftVal = (bIsNeg ? A_x_ratio1_x_fee1 - A_hat_x_ratio1_x_fee1 : A_hat_x_ratio1_x_fee1 - A_x_ratio1_x_fee1) / ratio0;
            }
            if(bIsNeg) {
                // [B*fee1 - leftVal] / fee2 + B_hat
                uint256 B_x_fee1 = tokensHeld1 * fee1;
                bIsNeg = B_x_fee1 < leftVal;
                if(!bIsNeg) {
                    b = (B_x_fee1 - leftVal) / fee2 + reserve1;
                } else {
                    leftVal = (leftVal - B_x_fee1) / fee2; // remains negative
                    // B_hat - leftVal1
                    bIsNeg = reserve1 < leftVal;
                    b = bIsNeg ? leftVal - reserve1 : reserve1 - leftVal;
                }
            } else {
                // [leftVal + B*fee1] / fee2 + B_hat
                b = (leftVal + tokensHeld1 * fee1) / fee2 + reserve1;
            }
        }

        bool cIsNeg;
        uint256 c;
        {
            // c = (A*P - B)*A_hat*fee
            //   = (A*ratio1/ratio0 - B)*A_hat*fee1/fee2
            //   = [(A*ratio1*fee1/ratio0)*A_hat - B*A_hat*fee1]/fee2
            uint256 leftVal = (tokensHeld0 * ratio1 * fee1 / ratio0) * reserve0;
            uint256 rightVal = tokensHeld1 * reserve0 * fee1;
            cIsNeg = leftVal < rightVal;
            c = (cIsNeg ? rightVal - leftVal : leftVal - rightVal) / fee2;
        }

        uint256 det;
        {
            // sqrt(b^2 + 4*a*c) because a is negative
            uint256 leftVal = b**2; // expanded
            uint256 rightVal = c * fee1 * ratio1 / (fee2 * ratio0); // c was previously expanded
            rightVal = 4 * rightVal;
            if(cIsNeg) {
                //sqrt(b^2 - 4*a*c)
                if(leftVal > rightVal) {
                    det = Math.sqrt(leftVal - rightVal); // since both are expanded, will contract to correct value
                } else {
                    return deltas; // results in imaginary number
                }
            } else {
                //sqrt(b^2 + 4*a*c)
                det = Math.sqrt(leftVal + rightVal); // since both are expanded, will contract to correct value
            }
        }

        deltas = new int256[](2);
        // remember that a is always negative
        // root = (-b +/- det)/(2a)
        if(bIsNeg) { // b < 0
            // plus version
            // (b + det)/-2a = -(b + det)/2a
            // this is always negative
            deltas[0] = -int256((b + det) * fee2 * ratio0 / (2 * fee1 * ratio1));

            // minus version
            // (b - det)/-2a = (det-b)/2a
            if(det > b) {
                // x2 is positive
                deltas[1] = int256((det - b) * fee2 * ratio0 / (2 * fee1 * ratio1));
            } else {
                // x2 is negative
                deltas[1]= -int256((b - det) * fee2 * ratio0 / (2 * fee1 * ratio1));
            }
        } else { // b > 0
            // plus version
            // (-b + det)/-2a = (b - det)/2a
            if(b > det) {
                //  x1 is positive
                deltas[0] = int256((b - det) * fee2 * ratio0 / (2 * fee1 * ratio1));
            } else {
                //  x1 is negative
                deltas[0] = -int256((det - b) * fee2 * ratio0 / (2 * fee1 * ratio1));
            }

            // minus version
            // (-b - det)/-2a = (b+det)/2a
            deltas[1] = int256((b + det) * fee2 * ratio0 / (2 * fee1 * ratio1));
        }
    }

    /// @dev See {ICPMMMath-calcDeltasForWithdrawal}.
    /// @notice The calculation takes into consideration the market impact the transaction would have
    /// @notice The equation is derived from solving the quadratic root formula taking into account trading fees
    /// @notice This equation should always result in a recommendation to purchase token0 (a positive number)
    /// @notice Since a negative quadratic root means selling, if the result is negative, then the result is wrong
    /// @notice We can flip the reserves, tokensHeld, and ratio to turn a purchase of token0 into a sale of token0
    function calcDeltasForWithdrawal(uint256 amount, uint256 tokensHeld0, uint256 tokensHeld1, uint256 reserve0, uint256 reserve1,
        uint256 ratio0, uint256 ratio1, uint256 fee1, uint256 fee2) external virtual override pure returns(int256[] memory deltas) {
        // a = 1
        bool bIsNeg;
        uint256 b;
        {
            // b = -[C + A_hat - A + (1/P)*(B + B_hat/fee)]
            //   = -C - A_hat + A - [(B/P) + B_hat/(fee*P)]
            //   = -[C + A_hat] + A - [(B/P) + B_hat/(fee*P)]
            //   = -[C + A_hat] + A - [(B + B_hat/fee)(1/P)]
            //   = -[C + A_hat] + A - [(B + B_hat*fee2/fee1)*ratio0/ratio1]
            //   = -[C + A_hat] + A - [(B*ratio0 + B_hat*fee2*ratio0/fee1)/ratio1]
            //   = A - [(B*ratio0 + B_hat*fee2*ratio0/fee1)/ratio1] - [C + A_hat]
            //   = A - ([(B*ratio0 + B_hat*fee2*ratio0/fee1)/ratio1] + [C + A_hat])
            uint256 rightVal = (tokensHeld1 * ratio0 * fee1 + reserve1 * fee2 * ratio0) / (fee1 * ratio1) + (amount + reserve0);
            bIsNeg = rightVal > reserve0;
            b = bIsNeg ? rightVal - reserve0 : reserve0 - rightVal;
        }

        bool cIsNeg;
        uint256 c;
        {
            // c = -A_hat*(A - C - B/P)
            //   = -A_hat*A + A_hat*C + A_hat*B/P
            //   = -A_hat*A + A_hat*C + A_hat*B*ratio0/ratio1
            //   = A_hat*C + A_hat*B*ratio0/ratio1 - A_hat*A
            uint256 leftVal = reserve0 * amount + reserve0 * tokensHeld1 * ratio0 / ratio1;
            uint256 rightVal = reserve0 * tokensHeld0;
            cIsNeg = rightVal > leftVal;
            c = cIsNeg ? rightVal - leftVal : leftVal - rightVal; // remains expanded
        }

        deltas = new int256[](2);
        uint256 det;
        {
            // sqrt(b^2 - 4*c)
            uint256 leftVal = b**2; // expanded
            uint256 rightVal = 4*c; // previously expanded
            if(cIsNeg) {
                // add
                det = Math.sqrt(leftVal + rightVal); // since both are expanded, will contract to correct value
            } else if(leftVal > rightVal) {
                // subtract
                det = Math.sqrt(leftVal - rightVal); // since both are expanded, will contract to correct value
            } else {
                return deltas; // leads to imaginary number, don't trade
            }
        }

        // a is not needed since it's just 1
        // root = [-b +/- det] / 2
        if(bIsNeg) {
            // [b +/- det] / 2
            // plus version: (b + det) / 2
            deltas[0] = int256((b + det) / 2);

            // minus version: (b - det) / 2
            if(b > det) {
                deltas[1] = int256((b - det) / 2);
            } else {
                deltas[1] = -int256((det - b) / 2);
            }
        } else {
            // [-b +/- det] / 2
            // plus version: (det - b) / 2
            if(det > b) {
                deltas[0] = int256((det - b) / 2);
            } else {
                deltas[0] = -int256((b - det) / 2);
            }

            // minus version: -(b + det) / 2
            deltas[1] = -int256((b + det) / 2);
        }
    }
}
