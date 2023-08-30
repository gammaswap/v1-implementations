// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../interfaces/math/ICPMMMath.sol";

/// @title Math library for CPMM strategies
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Math library for complex computations for CPMM strategies
contract CPMMMath is ICPMMMath {

    error ZeroTokensHeld();
    error ZeroReserves();
    error ZeroFees();
    error ZeroRatio();
    error ZeroDecimals();
    error ComplexNumber();

    /// @dev See {ICPMMMath-calcCollateralPostTrade}
    function calcCollateralPostTrade(uint256 delta, uint256 tokensHeld0, uint256 tokensHeld1, uint256 reserve0, uint256 reserve1,
        uint256 fee1, uint256 fee2) external override virtual view returns(uint256 collateral) {
        if(tokensHeld0 == 0 || tokensHeld1 == 0) revert ZeroTokensHeld();
        if(reserve0 == 0 || reserve1 == 0) revert ZeroReserves();
        if(fee1 == 0 || fee2 == 0) revert ZeroFees();

        uint256 soldToken = reserve1 * delta * fee2 / ((reserve0 - delta) * fee1);
        require(soldToken <= tokensHeld1, "SOLD_TOKEN_GT_TOKENS_HELD1");

        tokensHeld1 -= soldToken;
        tokensHeld0 += delta;
        collateral = GSMath.sqrt(tokensHeld0 * tokensHeld1);
    }

    /// @dev See {ICPMMMath-calcDeltasForRatio}
    /// @notice The calculation takes into consideration the market impact the transaction would have
    /// @notice The equation is derived from solving the quadratic root formula taking into account trading fees
    /// @notice This equation should always result in a recommendation to purchase token0 (a positive number)
    /// @notice Since a negative quadratic root means selling, if the result is negative, then the result is wrong
    /// @notice We can flip the reserves, tokensHeld, and ratio to turn a purchase of token0 into a sale of token0
    function calcDeltasForMaxLP(uint256 tokensHeld0, uint256 tokensHeld1, uint256 reserve0, uint256 reserve1,
        uint256 fee1, uint256 fee2, uint8 decimals0) external virtual override view returns(int256[] memory deltas) {
        if(tokensHeld0 == 0 || tokensHeld1 == 0) revert ZeroTokensHeld();
        if(reserve0 == 0 || reserve1 == 0) revert ZeroReserves();
        if(fee1 == 0 || fee2 == 0) revert ZeroFees();
        if(decimals0 == 0) revert ZeroDecimals();
        // fee = fee1 / fee2 => fee2 > fee1 always
        // a = fee * (B_hat + B)
        uint256 a;
        {
            a = fee1 * (reserve1 + tokensHeld1) / fee2;
        }

        // b = -[2 * A_hat * B * fee + (L_hat ^ 2) * (1 + fee) + A * B_hat * (1 - fee)]
        //   = -[2 * A_hat * B * fee1 / fee2 + (L_hat ^ 2) * (fee2 + fee1) / fee2 + A * B_hat * (fee2 - fee1) / fee2];
        // b is always negative because fee2 > fee1 always
        uint256 b;
        {
            b = 2 * reserve0 * tokensHeld1 * fee1 / fee2;
            b = b + reserve0 * reserve1 * (fee2 + fee1) / fee2;
            b = b + tokensHeld0 * reserve1 * (fee2 - fee1) / fee2;
            b = b / (10 ** decimals0);
        }

        // c = A_hat * fee * (B * A_hat - A * B_hat)
        //   = A_hat * (B * A_hat - A * B_hat) * fee1 / fee2
        bool cIsNeg;
        uint256 c;
        {
            c = tokensHeld1 * reserve0;
            uint256 rightVal = tokensHeld0 * reserve1;
            (cIsNeg,c) = c > rightVal ? (false,c - rightVal) : (true,rightVal - c);
            c = c / (10**decimals0);
            c = (reserve0 * c * fee1 / fee2);
            c = c / (10**decimals0);
        }

        uint256 det;
        {
            // sqrt(b^2 - 4*a*c) because a is positive
            uint256 leftVal = b**2; // expanded
            uint256 rightVal = 4 * a * c;
            if(cIsNeg) {
                //sqrt(b^2 + 4*a*c)
                det = GSMath.sqrt(leftVal + rightVal); // since both are expanded, will contract to correct value
            } else {
                //sqrt(b^2 - 4*a*c)
                if(leftVal < rightVal) revert ComplexNumber();// results in imaginary number
                det = GSMath.sqrt(leftVal - rightVal); // since both are expanded, will contract to correct value
            }
        }

        deltas = new int256[](2);
        // remember that a is always positive and b is always negative
        // root = (-b +/- det)/(2a)
        // plus version
        // (-b + det)/2a = (b + det)/2a
        // this is always positive
        deltas[0] = int256((b + det) * (10 ** decimals0) / (2 * a));

        // minus version
        // (-b - det)/-2a = (b - det)/2a
        if(b > det) {
            // x2 is positive
            deltas[1] = int256((b - det) * (10 ** decimals0) / (2 * a));
        } else {
            // x2 is negative
            deltas[1]= -int256((det - b) * (10 ** decimals0) / (2 * a));
        }
    }

    /// @dev See {ICPMMMath-calcDeltasToCloseSetRatio}
    /// @notice The calculation takes into consideration the market impact the transaction would have
    /// @notice The equation is derived from solving the quadratic root formula taking into a   ccount trading fees
    /// @notice This equation should always result in a recommendation to purchase token0 (a positive number)
    /// @notice Since a negative quadratic root means selling, if the result is negative, then the result is wrong
    /// @notice We can flip the reserves, tokensHeld, and ratio to turn a purchase of token0 into a sale of token0
    function calcDeltasToCloseSetRatio(uint256 liquidity, uint256 ratio0, uint256 ratio1, uint256 tokensHeld0, uint256 tokensHeld1,
        uint256 reserve0, uint256 reserve1, uint8 decimals0, uint8 decimals1) external virtual override view returns(int256[] memory deltas) {
        if(tokensHeld0 == 0 || tokensHeld1 == 0) revert ZeroTokensHeld();
        if(reserve0 == 0 || reserve1 == 0) revert ZeroReserves();
        if(ratio0 == 0 || ratio1 == 0) revert ZeroRatio();
        if(decimals0 == 0 || decimals1 == 0) revert ZeroDecimals();
        // phi = liquidity / lastCFMMInvariant
        //     = L / L_hat

        // a = P * (1 + phi)
        //   = ratio1 * (1 + phi) / ratio0
        //   = ratio1 * (phiDec + phi) / ratio0
        //   = ratio1 * (L_hat + L) / (L_hat * ratio0)
        //   = ratio1 * (1 + L/L_hat) / ratio0
        //   = [ratio1 + (ratio1 * L / L_hat)] * decimals0 / ratio0

        uint256 a;

        bool bIsNeg;
        uint256 b;
        //   = (ratio1 / ratio0) + (ratio1 * liquidity) / (ratio0 * lastCFMMInvariant)
        //   = (ratio1 * lastCFMMInvariant + ratio1 * liquidity) / (ratio0 * lastCFMMInvariant)
        //   = ratio1 * (lastCFMMInvariant + liquidity) / (ratio0 * lastCFMMInvariant)
        //   = [ratio1 * (lastCFMMInvariant + liquidity) / ratio0 ] / lastCFMMInvariant
        //   = [ratio1 * (lastCFMMInvariant + liquidity) / ratio0 ] * invDecimals / lastCFMMInvariant
        {
            uint256 lastCFMMInvariant = GSMath.sqrt(reserve0 * reserve1);
            a = (ratio1 * (lastCFMMInvariant + liquidity) / ratio0);
            a = a * (10**((decimals0 + decimals0)/2)) / lastCFMMInvariant;

            // b = -(P * (A_hat * (2 * phi + 1) - A) + B + B_hat)
            //   = -(P * (A_hat * 2 * phi + A_hat - A) + B + B_hat)
            //   = -(P * A_hat * 2 * phi + P * A_hat - P * A + B + B_hat)
            //   = -(P * (A_hat * 2 * phi + A_hat - A) + B + B_hat)
            //   = -(P * (A_hat * 2 * liquidity / lastCFMMInvariant + A_hat - A) + B + B_hat)
            //   = -([ratio1 * (A_hat * 2 * liquidity / lastCFMMInvariant + A_hat - A) / ratio0] + B _ B_hat)
            {
                b = reserve0 * 2 * liquidity / lastCFMMInvariant + reserve0;
                (bIsNeg, b) = b > tokensHeld0 ? (false, ratio1 * (b - tokensHeld0) / ratio0) : (true, ratio1 * (tokensHeld0 - b) / ratio0);
                uint256 rightVal = reserve1 + tokensHeld1;
                if(bIsNeg) { // the sign changes because b is ultimately negated
                    (bIsNeg, b) = b > rightVal ? (false,b - rightVal) : (true,rightVal - b);
                } else {
                    (bIsNeg, b) = (true,b + rightVal);
                }
            }
        }
        // c = A_hat * [B - P * (A - A_hat * phi)] - L * L_hat
        //   = A_hat * [B - P * A + P * A_hat * phi] - L * L_hat
        //   = A_hat * B - A_hat * P * A + (A_hat ^ 2) * P * phi - L * L_hat
        //   = A_hat * B - A_hat * P * A + (A_hat ^ 2) * P * L / L_hat - L * L_hat;
        //   = A_hat * B - A_hat * P * A + [(A_hat ^ 2) * P / L_hat - L_hat] * L;
        //   = A_hat * B - A_hat * P * A + [(A_hat ^ 2) * P - L_hat ^ 2] * L / L_hat;
        //   = A_hat * B - A_hat * P * A + [(A_hat ^ 2) * P - A_hat * B_hat] * L / L_hat;
        //   = A_hat * B - A_hat * P * A + A_hat * [A_hat * P - B_hat] * L / L_hat;
        //   = A_hat * [B - P * A + (A_hat * P - B_hat) * L / L_hat];
        //   = A_hat * [B - P * A - (B_hat - A_hat * P) * L / L_hat];
        //   = - A_hat * [P * A + (B_hat - A_hat * P) * L / L_hat - B];
        bool cIsNeg;
        uint256 c;
        {
            c = reserve0 * ratio1 / ratio0;
            (cIsNeg,c) = reserve1 > c ? (false,reserve1 - c) : (true, c - reserve1);
            c = c * liquidity / GSMath.sqrt(reserve0 * reserve1);
            if(cIsNeg) {
                c = c + tokensHeld1;
                uint256 leftVal = tokensHeld0 * ratio1 / ratio0;
                (cIsNeg,c) = leftVal > c ? (false, leftVal - c) : (true, c - leftVal);
            } else {
                c = c + tokensHeld0 * ratio1 / ratio0;
                (cIsNeg,c) = c > tokensHeld1 ? (false,c - tokensHeld1) : (true,tokensHeld1 - c);
            }

            (cIsNeg,c) = (!cIsNeg, reserve0 * c);
        }

        uint256 det;
        {
            // sqrt(b^2 - 4*a*c) because a is positive
            uint256 leftVal = b**2; // expanded
            uint256 rightVal = 4 * a * c / (10 ** decimals0);
            if(cIsNeg) {
                //sqrt(b^2 + 4*a*c)
                det = GSMath.sqrt(leftVal + rightVal); // since both are expanded, will contract to correct value
            } else {
                //sqrt(b^2 - 4*a*c)
                if(leftVal < rightVal) revert ComplexNumber(); // results in imaginary number
                det = GSMath.sqrt(leftVal - rightVal); // since both are expanded, will contract to correct value
            }
        }

        deltas = new int256[](2);
        // remember that a is always positive
        // root = (-b +/- det)/(2a)
        if(bIsNeg) { // b < 0
            // plus version
            // (-b + det)/2a = (b + det)/2a
            // this is always positive
            deltas[0] = int256((b + det) * (10**decimals1) / (2 * a));

            // minus version
            // (-b - det)/-2a = (b - det)/2a
            if(b > det) {
                // x2 is positive
                deltas[1] = int256((b - det) * (10**decimals1) / (2 * a));
            } else {
                // x2 is negative
                deltas[1]= -int256((det - b) * (10**decimals1) / (2 * a));
            }
        } else { // b > 0
            // plus version
            // (-b + det)/2a = (det - b)/2a
            if(det > b) {
                //  x1 is positive
                deltas[0] = int256((det - b) * (10**decimals1) / (2 * a));
            } else {
                //  x1 is negative
                deltas[0] = -int256((b - det) * (10**decimals1) / (2 * a));
            }

            // minus version
            // (-b - det)/-2a = -(b + det)/2a
            deltas[1] = -int256((b + det) * (10**decimals1) / (2 * a));
        }
    }

    /// @dev See {ICPMMMath-calcDeltasToClose}
    /// @notice how much collateral to trade to have enough to close a position
    /// @notice reserve and collateral have to be of the same token
    /// @notice if > 0 => have to buy token to have exact amount of token to close position
    /// @notice if < 0 => have to sell token to have exact amount of token to close position
    function calcDeltasToClose(uint256 liquidity, uint256 lastCFMMInvariant, uint256 collateral, uint256 reserve)
        external virtual override pure returns(int256 delta) {
        require(lastCFMMInvariant > 0, "ZERO_CFMM_INVARIANT");
        require(collateral > 0, "ZERO_COLLATERAL");
        if(reserve == 0) revert ZeroReserves();

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
    function calcDeltasForRatio(uint256 ratio0, uint256 ratio1, uint256 tokensHeld0, uint256 tokensHeld1,
        uint256 reserve0, uint256 reserve1, uint256 fee1, uint256 fee2) external virtual override view returns(int256[] memory deltas) {
        if(tokensHeld0 == 0 || tokensHeld1 == 0) revert ZeroTokensHeld();
        if(reserve0 == 0 || reserve1 == 0) revert ZeroReserves();
        if(ratio0 == 0 || ratio1 == 0) revert ZeroRatio();
        if(fee1 == 0 || fee2 == 0) revert ZeroFees();
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
                if(leftVal < rightVal) revert ComplexNumber(); // results in imaginary number
                det = GSMath.sqrt(leftVal - rightVal); // since both are expanded, will contract to correct value
            } else {
                //sqrt(b^2 + 4*a*c)
                det = GSMath.sqrt(leftVal + rightVal); // since both are expanded, will contract to correct value
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
    function calcDeltasForWithdrawal(uint256 amount, uint256 ratio0, uint256 ratio1, uint256 tokensHeld0, uint256 tokensHeld1,
        uint256 reserve0, uint256 reserve1, uint256 fee1, uint256 fee2) external virtual override pure returns(int256[] memory deltas) {
        if(tokensHeld0 == 0 || tokensHeld1 == 0) revert ZeroTokensHeld();
        if(reserve0 == 0 || reserve1 == 0) revert ZeroReserves();
        if(ratio0 == 0 || ratio1 == 0) revert ZeroRatio();
        if(fee1 == 0 || fee2 == 0) revert ZeroFees();
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
                det = GSMath.sqrt(leftVal + rightVal); // since both are expanded, will contract to correct value
            } else {
                if(leftVal < rightVal) revert ComplexNumber(); // imaginary number
                det = GSMath.sqrt(leftVal - rightVal); // since both are expanded, will contract to correct value
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
