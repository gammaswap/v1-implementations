// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷c) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param c The divisor
    /// @return r The 256-bit result
    function mulDiv256(uint256 a, uint256 b, uint256 c) internal pure returns(uint256) {
        (uint256 r0, uint256 r1) = mulDiv512(a, b, c);

        require(r1 == 0, "MULDIV_OVERFLOW");

        return r0;
    }

    /// @notice Calculates floor(a×b÷c) with full precision and returns a 512 bit number. Never overflows
    /// @notice Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param c The divisor
    /// @return r0 lower bits of result of division
    /// @return r1 lower bits of result of division
    function mulDiv512(uint256 a, uint256 b, uint256 c) internal pure returns(uint256 r0, uint256 r1) {
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
        (r0, r1) = div512x256(a0, a1, c);
    }

    /// @notice Calculates the remainder of a division of a 512 bit unsigned integer by a 256 bit integer.
    /// @param a0 A uint256 representing the low bits of the numerator.
    /// @param a1 A uint256 representing the high bits of the numerator.
    /// @param b A uint256 representing the denominator.
    /// @return rem A uint256 representing the remainder of the division.
    function divRem512x256(uint256 a0, uint256 a1, uint256 b) internal pure returns(uint256 rem) {
        require(b != 0, "DIVISION_BY_ZERO");

        assembly {
            rem := mulmod(a1, not(0), b)
            rem := addmod(rem, a1, b)
            rem := addmod(rem, a0, b)
        }
    }

    /// @notice Calculates the division of a 512 bit unsigned integer by a 256 bit integer.
    /// @dev Source https://medium.com/wicketh/mathemagic-512-bit-division-in-solidity-afa55870a65
    /// @param a0 uint256 representing the lower bits of the numerator.
    /// @param a1 uint256 representing the higher bits of the numerator.
    /// @param b uint256 denominator.
    /// @return r0 lower bits of the uint512 quotient.
    /// @return r1 higher bits of the uint512 quotient.
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

        assembly {
            let tmp := add(r0, div(a0,b))
            r1 := add(add(r1, 0), lt(tmp, r0))
            r0 := tmp
        }

        return (r0, r1);
    }

    /// @notice Calculate the product of two uint256 numbers. Never overflows
    /// @dev Source https://medium.com/wicketh/mathemagic-full-multiply-27650fec525d
    /// @param a first number (uint256).
    /// @param b second number (uint256).
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function mul256x256(uint256 a, uint256 b) internal pure returns (uint256 r0, uint256 r1) {
        assembly {
            let mm := mulmod(a, b, not(0))
            r0 := mul(a, b)
            r1 := sub(sub(mm, r0), lt(mm, r0))
        }
    }

    /// @notice Calculates the product of a uint512 and a uint256 number
    /// @dev Source https://medium.com/wicketh/mathemagic-512-bit-division-in-solidity-afa55870a65
    /// @param a0 lower bits of first number.
    /// @param a1 higher bits of first number.
    /// @param b second number (uint256).
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function mul512x256(uint256 a0, uint256 a1, uint256 b) internal pure returns (uint256 r0, uint256 r1) {
        uint256 ff;

        assembly {
            let mm := mulmod(a0, b, not(0))
            r0 := mul(a0, b)
            let cc := sub(sub(mm, r0), lt(mm, r0)) // carry from a0*b

            mm := mulmod(a1, b, not(0))
            let ab := mul(a1, b)
            ff := sub(sub(mm, ab), lt(mm, ab)) // carry from a1*b

            r1 := add(cc, ab)

            ff := or(ff, lt(r1,ab)) // overflow from (a0,a1)*b
        }

        require(ff < 1, "MULTIPLICATION_OVERFLOW");
    }

    /// @notice Calculates the sum of two uint512 numbers
    /// @dev Source https://medium.com/wicketh/mathemagic-512-bit-division-in-solidity-afa55870a65
    /// @param a0 lower bits of first number.
    /// @param a1 higher bits of first number.
    /// @param b0 lower bits of second number.
    /// @param b1 higher bits of second number.
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function add512x512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (uint256 r0, uint256 r1) {
        uint256 ff;

        assembly {
            let rr := add(a1, b1)
            ff := lt(rr, a1)  // carry from a1+b1
            r0 := add(a0, b0)
            r1 := add(rr, lt(r0, a0)) // add carry from a0+b0
            ff := or(ff,lt(r1, rr))
        }

        require(ff < 1, "ADDITION_OVERFLOW");
    }

    /// @notice Calculates the difference of two uint512 numbers
    /// @dev Source https://medium.com/wicketh/mathemagic-512-bit-division-in-solidity-afa55870a65
    /// @param a0 lower bits of first number.
    /// @param a1 higher bits of first number.
    /// @param b0 lower bits of second number.
    /// @param b1 higher bits of second number.
    /// @return r0 The result as an uint512. (lower bits).
    /// @return r1 The result as an uint512. (higher bits).
    function sub512x512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (uint256 r0, uint256 r1) {
        require(ge512(a0, a1, b0, b1), "SUBTRACTION_UNDERFLOW");

        assembly {
            r0 := sub(a0, b0)
            r1 := sub(sub(a1, b1), lt(a0, b0))
        }
    }

    /// @dev Returns the square root of `a`.
    /// @param a number to square root
    /// @return z square root of a
    function sqrt256(uint256 a) internal pure returns (uint256 z) {
        if (a == 0) return 0;

        assembly {
            z := 181 // Should be 1, but this saves a multiplication later.

            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, a))
            r := or(shl(6, lt(0xffffffffffffffffff, shr(r, a))), r)
            r := or(shl(5, lt(0xffffffffff, shr(r, a))), r)
            r := or(shl(4, lt(0xffffff, shr(r, a))), r)
            z := shl(shr(1, r), z)

            // Doesn't overflow since y < 2**136 after above.
            z := shr(18, mul(z, add(shr(r, a), 65536))) // A mul() saved from z = 181.

            // Given worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))
            z := shr(1, add(div(a, z), z))

            // If x+1 is a perfect square, the Babylonian method cycles between floor(sqrt(x)) and ceil(sqrt(x)).
            // We always return floor. Source https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            z := sub(z, lt(div(a, z), z))
        }
    }

    /// @notice Calculates the square root of a 512 bit unsigned integer, rounds down.
    /// @dev Uses Karatsuba Square Root method. Source https://hal.inria.fr/inria-00072854/document.
    /// @param a0 lower bits of 512 bit number.
    /// @param a1 higher bits of 512 bit number.
    /// @return z The square root as an uint256 of a 512 bit number.
    function sqrt512(uint256 a0, uint256 a1) internal pure returns (uint256 z) {
        if (a1 == 0) return sqrt256(a0);

        uint256 shift;

        assembly {
            let bits := mul(128, lt(a1, 0x100000000000000000000000000000000))
            shift := add(bits, shift)
            a1 := shl(bits, a1)

            bits := mul(64, lt(a1, 0x1000000000000000000000000000000000000000000000000))
            shift := add(bits, shift)
            a1 := shl(bits, a1)

            bits := mul(32, lt(a1, 0x100000000000000000000000000000000000000000000000000000000))
            shift := add(bits, shift)
            a1 := shl(bits, a1)

            bits := mul(16, lt(a1, 0x1000000000000000000000000000000000000000000000000000000000000))
            shift := add(bits, shift)
            a1 := shl(bits, a1)

            bits := mul(8, lt(a1, 0x100000000000000000000000000000000000000000000000000000000000000))
            shift := add(bits, shift)
            a1 := shl(bits, a1)

            bits := mul(4, lt(a1, 0x1000000000000000000000000000000000000000000000000000000000000000))
            shift := add(bits, shift)
            a1 := shl(bits, a1)

            bits := mul(2, lt(a1, 0x4000000000000000000000000000000000000000000000000000000000000000))
            shift := add(bits, shift)
            a1 := shl(bits, a1)

            a1 := or(shr(sub(256, shift), a0), a1)
            a0 := shl(shift, a0)
        }

        uint256 z1 = sqrt256(a1);

        assembly {
            let rz := sub(a1, mul(z1, z1))
            let numerator := or(shl(128, rz), shr(128, a0))
            let denominator := shl(1, z1)

            let q := div(numerator, denominator)
            let r := mod(numerator, denominator)

            let carry := shr(128, rz)
            let x := mul(carry, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

            q := add(div(x, denominator), q)
            r := add(add(carry, mod(x, denominator)), r)
            q := add(div(r, denominator), q)
            r := mod(r, denominator)

            z := add(shl(128, z1), q)

            let rl := or(shl(128, r), and(a0, 0xffffffffffffffffffffffffffffffff))

            z := sub(z,gt(or(lt(shr(128, r),shr(128,q)),and(eq(shr(128, r), shr(128,q)),lt(rl,mul(q,q)))),0))
            z := shr(div(shift,2), z)
        }
    }

    function eq512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (bool) {
        return a1 == b1 && a0 == b0;
    }

    function gt512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (bool) {
        return a1 > b1 || (a1 == b1 && a0 > b0);
    }

    function lt512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (bool) {
        return a1 < b1 || (a1 == b1 && a0 < b0);
    }

    function ge512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (bool) {
        return a1 > b1 || (a1 == b1 && a0 >= b0);
    }

    function le512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (bool) {
        return a1 < b1 || (a1 == b1 && a0 <= b0);
    }
}