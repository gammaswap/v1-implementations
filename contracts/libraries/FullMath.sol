// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal view returns (uint256 result) {
        result = mulDiv256(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }

    function div256(uint256 a) internal pure returns(uint256 r) {
        require(a > 1);
        assembly {
            r := add(div(sub(0, a), a), 1)
        }
    }

    function mod256(uint256 a) internal pure returns(uint256 r) {
        require(a != 0);
        assembly {
            r := mod(sub(0, a), a)
        }
    }

    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param c The divisor
    /// @return r The 256-bit result
    function mulDiv256b(uint256 a, uint256 b, uint256 c) internal view returns(uint256) {
        require(c != 0, "MULDIV_ZERO_DIVISOR"); // satisfies c != 0

        (uint256 r0, uint256 r1) = mul256x256(a, b);
        (r0, r1) = div512x256(r0, r1, c);

        require(r1 == 0, "MULDIV_OVERFLOW");

        return r0;
    }


    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param c The divisor
    /// @return r The 256-bit result
    function mulDiv256(uint256 a, uint256 b, uint256 c) internal view returns(uint256) {
        (uint256 r0, uint256 r1) = mulDiv512(a, b, c);

        require(r1 == 0, "MULDIV_OVERFLOW");

        return r0;
    }

    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param c The divisor
    /// @return r The 256-bit result
    function mulDiv512(uint256 a, uint256 b, uint256 c) internal view returns(uint256, uint256) {
        require(c != 0, "MULDIV_ZERO_DIVISOR");

        // mul256x256

        uint256 a0;
        uint256 a1;
        assembly {
            let mm := mulmod(a, b, not(0))
            a0 := mul(a, b)
            a1 := sub(sub(mm, a0), lt(mm, a0))
        }

        // div512x256
        return div512x256(a0, a1, c);
    }

    function divRem512x256(uint256 a0, uint256 a1, uint256 b) internal pure returns(uint256 rem) {
        require(b != 0, "DIVISION_BY_ZERO");

        assembly {
            // calculate the remainder
            rem := mulmod(a1, not(0), b)
            rem := addmod(rem, a1, b)
            rem := addmod(rem, a0, b)
        }
    }

    function div512x256(uint256 a0, uint256 a1, uint256 b) internal pure returns(uint256 r0, uint256 r1) {
        require(b != 0, "DIVISION_BY_ZERO");

        if(a1 == 0) {
            return (a0 / b, 0);
        }

        if(b == 1) {
            return (a0, a1);
        }

        uint256 q;
        uint256 r;

        assembly {
            q := add(div(sub(0, b), b), 1)
            r := mod(sub(0, b), b)
        }

        uint256 t0;
        uint256 t1;

        while(a1 != 0) {
            assembly {
                // (t0,t1) = a1 x q
                let mm := mulmod(a1, q, not(0))
                t0 := mul(a1, q)
                t1 := sub(sub(mm, t0), lt(mm, t0))

                // (r0,r1) = (r0,r1) + (t0,t1)
                let tmp := add(r0, t0)
                r1 := add(add(r1, t1), lt(tmp, r0))
                r0 := tmp

                // (t0,t1) = a1 x r
                mm := mulmod(a1, r, not(0))
                t0 := mul(a1, r)
                t1 := sub(sub(mm, t0), lt(mm, t0))

                // (a0,a1) = (t0,t1) + (a0,0)
                a0 := add(t0, a0)
                a1 := add(add(t1, 0), lt(a0, t0))
            }
        }

        uint256 c;

        unchecked {
            c = a0 / b;
        }

        assembly {
            let tmp := add(r0, c)
            r1 := add(add(r1, 0), lt(tmp, r0))
            r0 := tmp
        }

        return (r0, r1);
    }

    function div512x256b(uint256 a0, uint256 a1, uint256 b) internal pure returns(uint256 r0, uint256 r1) {
        uint256 q = div256(b);
        uint256 r = mod256(b);
        uint256 t0;
        uint256 t1;
        while(a1 != 0) {
            (t0, t1) = mul256x256(a1, q);
            (r0, r1) = add512x512(r0, r1, t0, t1);
            (t0, t1) = mul256x256(a1, r);
            (a0, a1) = add512x512(t0, t1, a0, 0);
        }
        (r0, r1) = add512x512(r0, r1, a0 / b, 0);
    }

    /// @notice Calculate the product of two uint256 numbers
    /// @param a first number (uint256).
    /// @param b second number (uint256).
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function mul256x256(uint256 a, uint256 b) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            let mm := mulmod(a, b, not(0))
            r0 := mul(a, b)
            r1 := sub(sub(mm, r0), lt(mm, r0))
        }
    }

    /// @notice Calculates the product of a uint512 and a uint256 number
    /// @param a0 lower bits of first number.
    /// @param a1 higher bits of first number.
    /// @param b second number (uint256).
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function mul512x256(uint256 a0, uint256 a1, uint256 b) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            let mm := mulmod(a0, b, not(0))
            r0 := mul(a0, b)
            r1 := sub(sub(mm, r0), lt(mm, r0))
            r1 := add(r1, mul(a1, b))
        }
    }

    /// @notice Calculates the sum of two uint512 numbers
    /// @param a0 lower bits of first number.
    /// @param a1 higher bits of first number.
    /// @param b0 lower bits of second number.
    /// @param b1 higher bits of second number.
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function add512x512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            r0 := add(a0, b0)
            r1 := add(add(a1, b1), lt(r0, a0))
        }
    }

    /// @notice Calculates the difference of two uint512 numbers
    /// @param a0 lower bits of first number.
    /// @param a1 higher bits of first number.
    /// @param b0 lower bits of second number.
    /// @param b1 higher bits of second number.
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function sub512x512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            r0 := sub(a0, b0)
            r1 := sub(sub(a1, b1), lt(a0, b0))
        }
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    function sqrt256(uint256 x) public pure returns (uint256 s) {

        if (x == 0) return 0;

        assembly {

            s := 1

            let xAux := x

            let cmp := or(gt(xAux, 0x100000000000000000000000000000000), eq(xAux, 0x100000000000000000000000000000000))
            xAux := sar(mul(cmp, 128), xAux)
            s := shl(mul(cmp, 64), s)

            cmp := or(gt(xAux, 0x10000000000000000), eq(xAux, 0x10000000000000000))
            xAux := sar(mul(cmp, 64), xAux)
            s := shl(mul(cmp, 32), s)

            cmp := or(gt(xAux, 0x100000000), eq(xAux, 0x100000000))
            xAux := sar(mul(cmp, 32), xAux)
            s := shl(mul(cmp, 16), s)

            cmp := or(gt(xAux, 0x10000), eq(xAux, 0x10000))
            xAux := sar(mul(cmp, 16), xAux)
            s := shl(mul(cmp, 8), s)

            cmp := or(gt(xAux, 0x100), eq(xAux, 0x100))
            xAux := sar(mul(cmp, 8), xAux)
            s := shl(mul(cmp, 4), s)

            cmp := or(gt(xAux, 0x10), eq(xAux, 0x10))
            xAux := sar(mul(cmp, 4), xAux)
            s := shl(mul(cmp, 2), s)

            s := shl(mul(or(gt(xAux, 0x8), eq(xAux, 0x8)), 2), s)
        }

        unchecked {
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            uint256 roundedDownResult = x / s;
            return s >= roundedDownResult ? roundedDownResult : s;
        }
    }

    /// @notice Calculates the square root of a 512 bit unsigned integer (rounds down).
    /// @dev Uses the Karatsuba Square Root method. See https://hal.inria.fr/inria-00072854/document for details.
    /// @param a0 lower bits of first number.
    /// @param a1 higher bits of first number.
    /// @return s The square root as an uint256 of a 512 bit number.
    function sqrt512(uint256 a0, uint256 a1) public pure returns (uint256 s) {

        // 256 bit square root is sufficient
        if (a1 == 0) return sqrt256(a0);

        // Algorithm below has pre-condition a1 >= 2**254
        uint256 shift;

        assembly {
            let digits := mul(lt(a1, 0x100000000000000000000000000000000), 128)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(lt(a1, 0x1000000000000000000000000000000000000000000000000), 64)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(lt(a1, 0x100000000000000000000000000000000000000000000000000000000), 32)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(lt(a1, 0x1000000000000000000000000000000000000000000000000000000000000), 16)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(lt(a1, 0x100000000000000000000000000000000000000000000000000000000000000), 8)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(lt(a1, 0x1000000000000000000000000000000000000000000000000000000000000000), 4)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(lt(a1, 0x4000000000000000000000000000000000000000000000000000000000000000), 2)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            a1 := or(a1, shr(sub(256, shift), a0))
            a0 := shl(shift, a0)
        }

        uint256 sp = sqrt256(a1);
        uint256 rp = a1 - (sp * sp);

        uint256 nom;
        uint256 denom;
        uint256 u;
        uint256 q;

        assembly {
            nom := or(shl(128, rp), shr(128, a0))
            denom := shl(1, sp)
            q := div(nom, denom)
            u := mod(nom, denom)

            let carry := shr(128, rp)
            let x := mul(carry, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            q := add(q, div(x, denom))
            u := add(u, add(carry, mod(x, denom)))
            q := add(q, div(u, denom))
            u := mod(u, denom)
        }

        unchecked {
            s = (sp << 128) + q;

            uint256 rl = ((u << 128) | (a0 & 0xffffffffffffffffffffffffffffffff));
            uint256 rr = q * q;

            if ((q >> 128) > (u >> 128) || (((q >> 128) == (u >> 128)) && rl < rr)) {
                s = s - 1;
            }

            return s >> (shift / 2);
        }
    }

    function eq512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public pure returns (bool) {
        return a1 == b1 && a0 == b0;
    }

    function gt512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public pure returns (bool) {
        return a1 > b1 || (a1 == b1 && a0 > b0);
    }

    function lt512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public pure returns (bool) {
        return a1 < b1 || (a1 == b1 && a0 < b0);
    }

    function ge512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public pure returns (bool) {
        return a1 > b1 || (a1 == b1 && a0 >= b0);
    }

    function le512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public pure returns (bool) {
        return a1 < b1 || (a1 == b1 && a0 <= b0);
    }

    function bitLength(uint256 n) public pure returns (uint256 length) {
        length = 0;
        while (n > 0) {
            length++;
            n >>= 1;
        }
    }
}