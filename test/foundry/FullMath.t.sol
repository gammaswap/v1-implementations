pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../../contracts/libraries/FullMath.sol";

contract FullMathTest is Test {

    function testSqrt(uint8 num1, uint8 num2) public {
        num1 = uint8(bound(num1, 1, 1000));
        num2 = uint8(bound(num2, 1, 1000));

        assertGt(GSMath.sqrt(uint256(num1) * num2), 0);
        assertEq(GSMath.sqrt(1), 1);
        assertEq(GSMath.sqrt(2), 1);
        assertEq(GSMath.sqrt(3), 1);
        assertEq(GSMath.sqrt(4), 2);
        assertEq(GSMath.sqrt(5), 2);
        assertEq(GSMath.sqrt(7), 2);
        assertEq(GSMath.sqrt(8), 2);
        assertEq(GSMath.sqrt(9), 3);
        assertEq(GSMath.sqrt(100), 10);
        assertEq(GSMath.sqrt(99), 9);
        assertEq(GSMath.sqrt(1000), 31);
        assertEq(GSMath.sqrt(10000), 100);
        uint256 num3 = uint256(type(uint112).max) * 101 / 100;
        assertGt(GSMath.sqrt(num3 * num3), 0);
    }

    function bitLength(uint256 n) public pure returns (uint256 length) {
        length = 0;
        while (n > 0) {
            length++;
            n >>= 1;
        }
    }

    function testSqrtNumSize() public {
        uint256 num1 = 0x100000000000000000000000000000000;
        assertEq(bitLength(num1), 256-128+1);
        num1 = 0x1000000000000000000000000000000000000000000000000;
        assertEq(bitLength(num1), 256-64+1);
        num1 = 0x100000000000000000000000000000000000000000000000000000000;
        assertEq(bitLength(num1), 256-32+1);
        num1 = 0x1000000000000000000000000000000000000000000000000000000000000;
        assertEq(bitLength(num1), 256-16+1);
        num1 = 0x100000000000000000000000000000000000000000000000000000000000000;
        assertEq(bitLength(num1), 256-8+1);
        num1 = 0x1000000000000000000000000000000000000000000000000000000000000000;
        assertEq(bitLength(num1), 256-4+1);
        num1 = 0x4000000000000000000000000000000000000000000000000000000000000000;
        assertEq(bitLength(num1), 256-2+1);
    }

    function testCompare512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public {
        uint256 c0;
        uint256 c1;
        if(FullMath.eq512(a0, a1, b0, b1)) {
            (c0, c1) = FullMath.sub512x512(a0, a1, b0, b1);
            assertEq(c0, 0);
            assertEq(c1, 0);
            assertEq(FullMath.le512(a0, a1, b0, b1), true);
            assertEq(FullMath.ge512(a0, a1, b0, b1), true);
        } else if(FullMath.lt512(a0, a1, b0, b1)) {
            (c0, c1) = FullMath.sub512x512(b0, b1, a0, a1);
            assertEq(c0 > 0 || c1 > 0, true);
            assertEq(FullMath.le512(a0, a1, b0, b1), true);
            assertEq(FullMath.ge512(a0, a1, b0, b1), false);
        } else if(FullMath.gt512(a0, a1, b0, b1)) {
            (c0, c1) = FullMath.sub512x512(a0, a1, b0, b1);
            assertEq(c0 > 0 || c1 > 0, true);
            assertEq(FullMath.le512(a0, a1, b0, b1), false);
            assertEq(FullMath.ge512(a0, a1, b0, b1), true);
        }
    }

    function testAdd512Fixed() public {
        (uint256 a0, uint256 a1) = FullMath.add512x512(1, 0, 1, 0);
        assertEq(a0, 2);
        assertEq(a1, 0);

        (a0, a1) = FullMath.add512x512(type(uint256).max, 0, 1, 0);
        assertEq(a0, 0);
        assertEq(a1, 1);

        (a0, a1) = FullMath.add512x512(type(uint256).max, 0, 2, 0);
        assertEq(a0, 1);
        assertEq(a1, 1);

        (a0, a1) = FullMath.add512x512(type(uint256).max, 0, 3, 0);
        assertEq(a0, 2);
        assertEq(a1, 1);

        (a0, a1) = FullMath.add512x512(0, 1, 1, 0);
        assertEq(a0, 1);
        assertEq(a1, 1);

        (a0, a1) = FullMath.add512x512(1, 1, 1, 0);
        assertEq(a0, 2);
        assertEq(a1, 1);

        (a0, a1) = FullMath.add512x512(0, 1, 0, 1);
        assertEq(a0, 0);
        assertEq(a1, 2);

        (a0, a1) = FullMath.add512x512(type(uint256).max, 0, 0, type(uint256).max);
        assertEq(a0, type(uint256).max);
        assertEq(a1, type(uint256).max);

        vm.expectRevert("ADDITION_OVERFLOW");
        (a0, a1) = FullMath.add512x512(1, 0, type(uint256).max, type(uint256).max);
    }

    function testAdd512Revert() public {
        vm.expectRevert("ADDITION_OVERFLOW");
        FullMath.add512x512(type(uint256).max, type(uint256).max, 1, 0);
    }

    function testAdd512Revert2() public {
        vm.expectRevert("ADDITION_OVERFLOW");
        FullMath.add512x512(0, type(uint256).max, 0, 1);
    }

    function testAdd512Revert3() public {
        vm.expectRevert("ADDITION_OVERFLOW");
        FullMath.add512x512(0, 1, 0, type(uint256).max);
    }

    function testAdd512Revert4() public {
        vm.expectRevert("ADDITION_OVERFLOW");
        FullMath.add512x512(0, type(uint256).max, 0, type(uint256).max);
    }

    function testAdd512Revert5() public {
        vm.expectRevert("ADDITION_OVERFLOW");
        (uint256 r0, uint256 r1) = FullMath.add512x512(type(uint256).max-2, type(uint256).max, 3, 0);
    }

    function testAddSubtract(uint256 num1, uint256 num2) public {
        (uint256 a0, uint256 a1) = FullMath.add512x512(num1, 0, num2, 0);
        bool hasHighBit = a1 > 0;

        (uint256 r0, uint256 r1) = FullMath.sub512x512(a0, a1, num1, 0);
        assertEq(r0, num2);
        assertEq(r1, 0);
        (r0, r1) = FullMath.sub512x512(a0, a1, num2, 0);
        assertEq(r0, num1);
        assertEq(r1, 0);
        assertEq(FullMath.ge512(a0, a1, num1, 0), true);
        assertEq(FullMath.ge512(a0, a1, num2, 0), true);

        (a0, a1) = FullMath.add512x512(num1, 0, 0, num2);
        (r0, r1) = FullMath.sub512x512(a0, a1, num1, 0);
        assertEq(r0, 0);
        assertEq(r1, num2);
        (r0, r1) = FullMath.sub512x512(a0, a1, 0, num2);
        assertEq(r0, num1);
        assertEq(r1, 0);
        assertEq(FullMath.ge512(a0, a1, num1, 0), true);
        assertEq(FullMath.ge512(a0, a1, num2, 0), true);

        (a0, a1) = FullMath.add512x512(0, num1, num2, 0);
        (r0, r1) = FullMath.sub512x512(a0, a1, 0, num1);
        assertEq(r0, num2);
        assertEq(r1, 0);

        (r0, r1) = FullMath.sub512x512(a0, a1, num2, 0);
        assertEq(r0, 0);
        assertEq(r1, num1);
        assertEq(FullMath.ge512(a0, a1, num1, 0), true);
        assertEq(FullMath.ge512(a0, a1, num2, 0), true);

        if(hasHighBit) {
            vm.expectRevert("ADDITION_OVERFLOW");
            FullMath.add512x512(0, num1, 0, num2);
        }
    }

    function testAdd512(uint256 num) public {
        (uint256 a0, uint256 a1) = FullMath.add512x512(0, 1, num, 0);
        assertEq(a0, num);
        assertEq(a1, 1);

        (a0, a1) = FullMath.add512x512(0, 0, num, 0);
        assertEq(a0, num);
        assertEq(a1, 0);

        (a0, a1) = FullMath.add512x512(0, 0, 0, num);
        assertEq(a0, 0);
        assertEq(a1, num);

        (a0, a1) = FullMath.add512x512(1, 0, 0, num);
        assertEq(a0, 1);
        assertEq(a1, num);

        (a0, a1) = FullMath.add512x512(1, 0, 1, num);
        assertEq(a0, 2);
        assertEq(a1, num);

        if(num > 0) {
            (a0, a1) = FullMath.add512x512(1, 0, type(uint256).max, num - 1);
            assertEq(a0, 0);
            assertEq(a1, num);
        }
    }

    function testSub512Fixed() public {
        (uint256 a0, uint256 a1) = FullMath.sub512x512(0, 1, type(uint256).max, 0);
        assertEq(a0, 1);
        assertEq(a1, 0);

        (a0, a1) = FullMath.sub512x512(0, 1, 1, 0);
        assertEq(a0, type(uint256).max);
        assertEq(a1, 0);

        (a0, a1) = FullMath.sub512x512(0, 1, 2, 0);
        assertEq(a0, type(uint256).max - 1);
        assertEq(a1, 0);

        vm.expectRevert("SUBTRACTION_UNDERFLOW");
        FullMath.sub512x512(0, 1, 1, 1);
    }

    function testSub512Revert() public {
        vm.expectRevert("SUBTRACTION_UNDERFLOW");
        FullMath.sub512x512(0, 0, 1, 0);
    }

    function testSub512Revert2() public {
        vm.expectRevert("SUBTRACTION_UNDERFLOW");
        FullMath.sub512x512(0, 0, 1, 0);
    }

    function testSub512Revert3() public {
        vm.expectRevert("SUBTRACTION_UNDERFLOW");
        FullMath.sub512x512(0, type(uint256).max, 1, type(uint256).max);
    }

    function testSub512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) public {
        uint256 c0;
        uint256 c1;
        if(FullMath.gt512(a0, a1, b0, b1)) {
            (c0, c1) = FullMath.sub512x512(a0, a1, b0, b1);
            assertEq(FullMath.gt512(c0, c1, 0, 0), true);
            vm.expectRevert("SUBTRACTION_UNDERFLOW");
            FullMath.sub512x512(b0, b1, a0, a1);
        } else if(FullMath.lt512(a0, a1, b0, b1)) {
            (c0, c1) = FullMath.sub512x512(b0, b1, a0, a1);
            assertEq(FullMath.gt512(c0, c1, 0, 0), true);
            vm.expectRevert("SUBTRACTION_UNDERFLOW");
            FullMath.sub512x512(a0, a1, b0, b1);
        } else {
            (c0, c1) = FullMath.sub512x512(a0, a1, b0, b1);
            assertEq(FullMath.eq512(c0, c1, 0, 0), true);
        }
    }

    function testSqrt512Fixed() public {
        uint256 x0 = 0;
        uint256 x1 = 1;
        uint256 root = FullMath.sqrt512(x0, x1);

        (uint256 a0, uint256 a1) = FullMath.mul256x256(root, root);
        assertEq(FullMath.eq512(a0, a1, x0, x1), true);

        (uint256 b0, uint256 b1) = FullMath.add512x512(type(uint256).max, 0, 1, 0);
        assertEq(b0, 0);
        assertEq(b1, 1);

        (uint256 c0, uint256 c1) = FullMath.sub512x512(b0, b1, type(uint256).max, 0);
        assertEq(c0, 1);
        assertEq(c1, 0);

        (uint256 d0, uint256 d1) = FullMath.sub512x512(b0, b1, 1, 0);
        assertEq(d0, type(uint256).max);
        assertEq(d1, 0);

        root = FullMath.sqrt512(type(uint256).max, type(uint128).max);
        assertEq(root, type(uint192).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint144).max);
        assertEq(root, type(uint200).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint160).max);
        assertEq(root, type(uint208).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint176).max);
        assertEq(root, type(uint216).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint192).max);
        assertEq(root, type(uint224).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint208).max);
        assertEq(root, type(uint232).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint224).max);
        assertEq(root, type(uint240).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint224).max);
        assertEq(root, type(uint240).max);

        root = FullMath.sqrt512(type(uint256).max, type(uint240).max);
        assertEq(root, type(uint248).max);

        root = FullMath.sqrt512(0, type(uint256).max);
        assertEq(root, type(uint256).max);

        (a0, a1) = FullMath.mul256x256(type(uint200).max, type(uint200).max);
        root = FullMath.sqrt512(a0, a1);
        assertEq(root, type(uint200).max);

        (a0, a1) = FullMath.mul256x256(type(uint240).max, type(uint240).max);
        root = FullMath.sqrt512(a0, a1);
        assertEq(root, type(uint240).max);

        (a0, a1) = FullMath.mul256x256(type(uint256).max, type(uint256).max);
        root = FullMath.sqrt512(a0, a1);
        assertEq(root, type(uint256).max);

        (a0, a1) = FullMath.mul256x256(type(uint136).max, type(uint200).max);
        root = FullMath.sqrt512(a0, a1);
        assertEq(root, type(uint168).max - (2**31));
    }

    function testSqrt512(uint256 num1, uint256 num2) public {
        //num1*num1
        (uint256 x0, uint256 x1) = FullMath.mul256x256(num1, num1);
        uint256 x = FullMath.sqrt512(x0, x1);
        assertEq(x, num1);

        (uint256 _x0, uint256 _x1) = FullMath.mul256x256(x, x);
        assertEq(x0, _x0);
        assertEq(x1, _x1);

        //num2*num2
        (uint256 y0, uint256 y1) = FullMath.mul256x256(num2, num2);
        uint256 y = FullMath.sqrt512(y0, y1);
        assertEq(y, num2);

        (uint256 _y0, uint256 _y1) = FullMath.mul256x256(y, y);
        assertEq(y0, _y0);
        assertEq(y1, _y1);

        if(num1 > 0 && num2 > 0 && num1 != num2) {
            //num1*num2
            (uint256 z0, uint256 z1) = FullMath.mul256x256(num1, num2);
            uint256 z = FullMath.sqrt512(z0, z1);

            // z = sqrt(x*y) => z*z = x*y
            // x = y => x*x = z*z = y*y || x < y => x*x < z*z < y*y
            if(FullMath.eq512(x0, x1, y0, y1)) {
                assertEq(x0, z0);
                assertEq(x1, z1);
                assertEq(y0, z0);
                assertEq(y1, z1);
                assertEq(x, z);
                assertEq(y, z);
            } else if(FullMath.lt512(x0, x1, y0, y1)) {
                (_y0, _y1) = FullMath.sub512x512(y0, y1, z0, z1);
                assertEq(FullMath.gt512(_y0, _y1, 0, 0), true);
                (_x0, _x1) = FullMath.sub512x512(z0, z1, x0, x1);
                assertEq(FullMath.gt512(_x0, _x1, 0, 0), true);

                assertEq(FullMath.lt512(x0, x1, z0, z1), true);
                assertEq(FullMath.gt512(y0, y1, z0, z1), true);

                assertLe(x, z); // equal because sqrt512 rounds down
                assertGt(y, z);
            } else {
                (_x0, _x1) = FullMath.sub512x512(x0, x1, z0, z1);
                assertEq(FullMath.gt512(_x0, _x1, 0, 0), true);
                (_y0, _y1) = FullMath.sub512x512(z0, z1, y0, y1);
                assertEq(FullMath.gt512(_y0, _y1, 0, 0), true);

                assertEq(FullMath.gt512(x0, x1, z0, z1), true);
                assertEq(FullMath.lt512(y0, y1, z0, z1), true);

                assertEq(FullMath.gt512(x0, x1, z0, z1), true);
                assertEq(FullMath.lt512(y0, y1, z0, z1), true);
                assertGt(x, z);
                assertLe(y, z); // equal because sqrt512 rounds down
            }
        }
    }

    function testSqrt256(uint128 num1) public {
        uint256 num2 = uint256(num1)*num1;
        uint256 v1 = FullMath.sqrt256(num2);
        assertEq(v1, num1);
        assertEq(v1*v1, num2);
    }

    function testSqrt256Fixed() public {
        uint256 num1 = 1;
        uint256 v1 = FullMath.sqrt256(num1);
        assertEq(v1, 1);

        num1 = 2;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 1);

        num1 = 4;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 2);

        num1 = 5;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 2);

        num1 = 6;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 2);

        num1 = 7;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 2);

        num1 = 8;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 2);

        num1 = 9;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 3);

        num1 = 10;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 3);

        num1 = 16;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 4);

        num1 = 17;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 4);

        num1 = 25;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 5);

        num1 = 26;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 5);

        num1 = type(uint8).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, 15);

        num1 = type(uint16).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, type(uint8).max);

        num1 = type(uint32).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, type(uint16).max);

        num1 = type(uint64).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, type(uint32).max);

        num1 = type(uint128).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, type(uint64).max);

        num1 = type(uint256).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, type(uint128).max);

        num1 = type(uint208).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, type(uint104).max);

        num1 = type(uint144).max;
        v1 = FullMath.sqrt256(num1);
        assertEq(v1, type(uint72).max);
    }

    function testMul256x256(uint256 num1, uint256 num2) public {
        (uint256 v0, uint256 v1) = FullMath.mul256x256(num1, num2);

        uint256 bitsLen = bitLength(num1) + bitLength(num2);
        if(bitsLen < 256) {
            assertEq(v0, num1*num2);
            assertEq(v1, 0);
        } else if(bitsLen > 264) {
            assertGt(v0, 0);
            assertGt(v1, 0);
        }
    }

    function testMul256x256Fixed() public {
        uint256 num1 = 5;
        uint256 num2 = 10;

        (uint256 v0, uint256 v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, 50);
        assertEq(v1, 0);

        num1 = 934219231824923428784367;
        num2 = 667281938139048572048920;
        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, num1*num2);
        assertEq(v1, 0);

        num1 = 934219231824923428784367667281938139048572048920;
        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, num1*num2);
        assertEq(v1, 0);

        num2 = 934219231824923428784367;
        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, num1*num2);
        assertEq(v1, 0);

        num1 = type(uint112).max;
        num2 = type(uint112).max;
        assertEq(num1*num2, uint256(type(uint224).max) - 2*uint256(type(uint112).max));

        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, num1*num2);
        assertEq(v1, 0);

        num1 = type(uint128).max;
        num2 = type(uint128).max;
        assertEq(num1*num2, uint256(type(uint256).max) - 2*uint256(type(uint128).max));

        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, num1*num2);
        assertEq(v1, 0);

        num1 = type(uint256).max;
        num2 = type(uint128).max;

        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, num1 - (num2 - 1));
        assertEq(v1, num2 - 1);

        num1 = type(uint144).max;
        num2 = type(uint128).max;

        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, type(uint256).max - uint256((type(uint144).max)) - uint256(type(uint128).max));
        assertEq(v1, type(uint16).max);

        num1 = type(uint208).max;
        num2 = type(uint80).max;

        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, type(uint256).max - uint256((type(uint208).max)) - uint256(type(uint80).max));
        assertEq(v1, type(uint32).max);

        num1 = type(uint256).max;
        num2 = type(uint256).max;

        (v0, v1) = FullMath.mul256x256(num1, num2);
        assertEq(v0, 1);
        assertEq(v1, num2 - 1);
    }

    function testMul512x256_128(uint128 a0, uint128 a1, uint128 b) public {
        (uint256 v0, uint256 v1) = FullMath.mul512x256(a0, a1, b);
        assertEq(v0, uint256(a0) * b);
        assertEq(v1, uint256(a1) * b);

        if(b > 0) {
            (v0, v1) = FullMath.div512x256(v0, v1, b);
            assertEq(v0, uint256(a0));
            assertEq(v1, uint256(a1));
        }
    }

    function testMul512x256_256(uint256 a0, uint128 a1, uint128 b) public {
        uint256 mm;
        uint256 r0;
        uint256 r;
        assembly {
            mm := mulmod(a0, b, not(0))
            r0 := mul(a0, b)
            r := sub(sub(mm, r0), lt(mm, r0))
        }
        (uint256 v0, uint256 v1) = FullMath.mul512x256(a0, a1, b);
        assertEq(v0, r0);
        assertEq(v1, uint256(a1) * b + r);

        if(b > 0) {
            (v0, v1) = FullMath.div512x256(v0, v1, b);
            assertEq(v0, uint256(a0));
            assertEq(v1, uint256(a1));
        }
    }

    function testMul512x256(uint256 num1, uint256 num2) public {
        (uint256 u0, uint256 u1) = FullMath.mul256x256(num1, num2);
        (uint256 v0, uint256 v1) = FullMath.mul512x256(num1, 0, num2);
        assertEq(v0, u0);
        assertEq(v1, u1);

        if(u1 > 0) {
            vm.expectRevert("MULTIPLICATION_OVERFLOW");
            (uint256 x0, uint256 x1) = FullMath.mul512x256(0, num1, num2);
        } else {
            if(num2 > 0) {
                (uint256 x0, uint256 x1) = FullMath.div512x256(v0, v1, num2);
                assertEq(x0, num1);
                assertEq(x1, 0);
            }

            if(num1 > 0) {
                (uint256 x0, uint256 x1) = FullMath.div512x256(v0, v1, num1);
                assertEq(x0, num2);
                assertEq(x1, 0);
            }
        }
    }

    function testMul512x256Revert(uint256 num1, uint256 num2, uint256 num3) public {
        (uint256 x0, uint256 x1) = FullMath.mul256x256(num1, num3);
        (uint256 u0, uint256 u1) = FullMath.mul256x256(num2, num3);

        if(u0 > 0 && u1 == 0 && x1 > 0) {
            (uint256 y0, uint256 y1) = FullMath.add512x512(u0, 0, x1, 0);
            if(y1 > 0) {
                vm.expectRevert("MULTIPLICATION_OVERFLOW");
                FullMath.mul512x256(num1, num2, num3);
            }
        }
    }

    function testMul512x256Revert1() public {
        uint256 num1 = type(uint256).max;
        uint256 num2 = type(uint256).max;
        uint256 num3 = 2;
        vm.expectRevert("MULTIPLICATION_OVERFLOW");
        FullMath.mul512x256(num1, num2, num3);
    }

    function testMul512x256Revert2() public {
        uint256 num1 = type(uint128).max;
        uint256 num2 = type(uint128).max;
        uint256 num3 = uint256(type(uint128).max)+2;

        (uint256 a0, uint256 a1) = FullMath.mul512x256(num1, num2, num3);
        (uint256 r0, uint256 r1) = FullMath.div512x256(a0, a1, num3);
        assertEq(r0, num1);
        assertEq(r1, num2);

        num1++;
        vm.expectRevert("MULTIPLICATION_OVERFLOW");
        FullMath.mul512x256(num1, num2, num3);
    }

    function testMul512x256Revert3() public {
        uint256 num1 = uint256(type(uint240).max) + uint256(type(uint104).max) + 2;
        uint256 num2 = uint256(type(uint120).max) + 1;
        uint256 num3 = uint256(type(uint136).max);

        (uint256 a0, uint256 a1) = FullMath.mul512x256(num1, num2, num3);
        (uint256 r0, uint256 r1) = FullMath.div512x256(a0, a1, num3);
        assertEq(r0, num1);
        assertEq(r1, num2);

        ++num1;
        vm.expectRevert("MULTIPLICATION_OVERFLOW");
        FullMath.mul512x256(num1, num2, num3);
    }

    function testMul512x256Fixed() public {
        uint256 num1 = 23948237429384;
        uint256 num2 = 0;
        uint256 num3 = 942304;

        (uint256 v0, uint256 v1) = FullMath.mul512x256(num1, num2, num3);
        assertEq(v0, num1*num3);
        assertEq(v1, 0);

        num1 = type(uint256).max;
        num2 = 0;
        num3 = type(uint256).max;
        (v0, v1) = FullMath.mul512x256(num1, num2, num3);

        (uint256 u0, uint256 u1) = FullMath.mul256x256(num1, num3);
        assertEq(v0, u0);
        assertEq(v1, u1);

        num1 = 100;
        num2 = 1;
        num3 = 2;
        (v0, v1) = FullMath.mul512x256(num1, num2, num3);

        (u0, u1) = FullMath.mul256x256(num1, num3);
        assertEq(v0, u0);
        assertEq(v1, num2*num3);

        num1 = 3841394028304;
        num2 = 4238420394230;
        num3 = 3482938492390;
        (v0, v1) = FullMath.mul512x256(num1, num2, num3);

        (u0, u1) = FullMath.mul256x256(num1, num3);
        assertEq(v0, u0);
        assertEq(v1, num2*num3);

        vm.expectRevert("MULTIPLICATION_OVERFLOW");
        FullMath.mul512x256(0, type(uint256).max, 2);
    }

    function testDivFixed512x256_128(uint128 num1, uint128 num2, uint128 num3) public {
        if(num1 < 1e3) num1 = 1e3;
        if(num2 < 1e3) num2 = 1e3;
        if(num3 < 1e3) num3 = 1e3;

        (uint256 u0, uint256 u1) = FullMath.mul256x256(num1, num2);
        assertEq(u1, 0);
        (uint256 x0, uint256 x1) = FullMath.div512x256(u0, u1, num3);
        assertEq(x1, 0);
        (uint256 v0, uint256 v1) = FullMath.mul512x256(x0, x1, num3);

        uint256 num4 = uint256(num1) * uint256(num2) / uint256(num3);
        num4 = num4 * uint256(num3);

        assertEq(v0, num4);
        assertEq(v1, 0);
    }

    function testDivFixed512x256() public {
        uint256 num1 = 93741238472389427349278349029384954239042938402345834950853409583;
        uint256 num2 = 83741238472389875203420342342734927834902938495345834950853409583;
        uint256 num3 = 2;

        (uint256 u0, uint256 u1) = FullMath.mul256x256(num1, num2);
        (uint256 x0, uint256 x1) = FullMath.div512x256(u0, u1, num3);
        uint256 rem = FullMath.divRem512x256(u0, u1, num3);
        (uint256 v0, uint256 v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num3 = 4;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num3 = 87429342384;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num3 = 8742934238493742893483924389102893423;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = 724239723984*1e50;
        num2 = 837833*1e50;
        num3 = 47293*1e32;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = type(uint256).max;
        num2 = type(uint256).max;
        num3 = 1;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0, 1);
        assertEq(v1, type(uint256).max - 1);
        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = type(uint256).max;
        num2 = type(uint256).max;
        num3 = type(uint256).max;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0, 1);
        assertEq(v1, type(uint256).max - 1);
        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = type(uint256).max;
        num2 = type(uint256).max;
        num3 = type(uint128).max;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0, 1);
        assertEq(v1, type(uint256).max - 1);
        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = type(uint256).max;
        num2 = type(uint128).max;
        num3 = type(uint128).max;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = 1;
        num2 = 1;
        num3 = 1;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = 0;
        num2 = 1;
        num3 = 1;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0, 0);
        assertEq(v1, 0);
        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = 1;
        num2 = 0;
        num3 = 1;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        (x0, x1) = FullMath.div512x256(u0, u1, num3);
        rem = FullMath.divRem512x256(u0, u1, num3);
        (v0, v1) = FullMath.mul512x256(x0, x1, num3);

        assertEq(v0, 0);
        assertEq(v1, 0);
        assertEq(v0 + rem, u0);
        assertEq(v1, u1);

        num1 = 1;
        num2 = 1;
        num3 = 0;
        (u0, u1) = FullMath.mul256x256(num1, num2);
        assertEq(u0, 1);
        assertEq(u1, 0);

        vm.expectRevert("DIVISION_BY_ZERO");
        FullMath.div512x256(u0, u1, num3);

        vm.expectRevert("DIVISION_BY_ZERO");
        FullMath.divRem512x256(u0, u1, num3);
    }

    function testDiv512x256(uint256 num1, uint256 num2, uint256 num3) public {
        if(num3 < 1) num3 = 1;

        (uint256 u0, uint256 u1) = FullMath.mul256x256(num1, num2);
        (uint256 x0, uint256 x1) = FullMath.div512x256(u0, u1, num3);
        uint256 rem = FullMath.divRem512x256(u0, u1, num3);
        (uint256 v0, uint256 v1) = FullMath.mul512x256(x0, x1, num3);
        (v0, v1) = FullMath.add512x512(v0, v1, rem, 0);

        assertEq(v0, u0);
        assertEq(v1, u1);

        if(num1 > 0 && num2 > 0) {
            (uint256 y0, uint256 y1) = FullMath.div512x256(v0, v1, num2);
            rem = FullMath.divRem512x256(v0, v1, num2);
            (y0, y1) = FullMath.add512x512(y0, y1, rem, 0);

            assertEq(y0, num1);
            assertEq(y1, 0);

            (y0, y1) = FullMath.div512x256(v0, v1, num1);
            rem = FullMath.divRem512x256(v0, v1, num2);
            (y0, y1) = FullMath.add512x512(y0, y1, rem, 0);

            assertEq(y0, num2);
            assertEq(y1, 0);
        }
    }

    function testMulDiv512(uint256 num1, uint256 num2, uint256 num3) public {
        if(num3 == 0) {
            vm.expectRevert("MULDIV_ZERO_DIVISOR");
            FullMath.mulDiv512(num1, num2, 0);
            return;
        }

        (uint256 u0, uint256 u1) = FullMath.mul256x256(num1, num2);
        (uint256 v0, uint256 v1) = FullMath.mulDiv512(num1, num2, 1);

        assertEq(u0, v0);
        assertEq(u1, v1);

        (u0, u1) = FullMath.div512x256(u0, u1, num3);
        (v0, v1) = FullMath.mulDiv512(num1, num2, num3);

        assertEq(u0, v0);
        assertEq(u1, v1);
    }

    function testMulDiv256(uint256 num1, uint256 num2, uint256 num3) public {
        if(num3 == 0) {
            vm.expectRevert("MULDIV_ZERO_DIVISOR");
            FullMath.mulDiv512(num1, num2, num3);
            return;
        }
        if(num1 == 0 || num2 ==0) {
            uint256 u0 = FullMath.mulDiv256(num1, num2, num3);
            assertEq(u0, 0);
            return;
        }
        uint256 bitsLen = bitLength(num1) + bitLength(num2);
        if(bitsLen < 256) {
            uint256 u0 = FullMath.mulDiv256(num1, num2, num3);
            assertEq(u0, num1*num2/num3);
            (uint256 v0, uint256 v1) = FullMath.mulDiv512(num1, num2, num3);
            assertEq(v0, u0);
            assertEq(v1, 0);
        } else {
            uint256 bitsLen3 = bitLength(num3);
            (,uint256 x1) = FullMath.mul256x256(num1, num2);
            uint256 r = x1/num3;
            if(bitsLen3 > bitsLen || r == 0) {
                uint256 u0 = FullMath.mulDiv256(num1, num2, num3);
                (uint256 v0, uint256 v1) = FullMath.mulDiv512(num1, num2, num3);
                assertEq(v0, u0);
                assertEq(v1, 0);
            } else {
                vm.expectRevert("MULDIV_OVERFLOW");
                FullMath.mulDiv256(num1, num2, num3);
            }
        }
    }
}
