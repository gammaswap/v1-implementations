// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./fixtures/CPMMGammaSwapSetup.sol";

contract CPMMLongStrategyTest is CPMMGammaSwapSetup {

    function setUp() public {
        super.initCPMMGammaSwap();
        depositLiquidityInCFMM(addr1, 2*1e24, 2*1e21);
        depositLiquidityInCFMM(addr2, 2*1e24, 2*1e21);
        depositLiquidityInPool(addr2);
    }

    function testBorrowAndRebalance(uint8 num1, uint8 num2) public {
        if(num1 == 0) {
            num1++;
        }
        if(num2 == 0) {
            num2++;
        }
        if(num1 == num2) {
            if(num1 < 255) {
                num1++;
            } else {
                num1--;
            }
        }

        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * 1e18 / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 2_000_000 * 1e18);
        weth.transfer(address(pool), 2000 * 1e18);

        uint128[] memory collateral = pool.increaseCollateral(tokenId);

        uint256[] memory ratio = new uint256[](2);
        ratio[0] = uint256(reserve0) * num1;
        ratio[1] = uint256(reserve1) * num2;

        uint256 desiredRatio = ratio[1] * 1e18 / ratio[0];

        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/100, ratio);
        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];

        vm.stopPrank();

        uint256 diff = strikePx > desiredRatio ? strikePx - desiredRatio : desiredRatio - strikePx;
        assertEq(diff/1e12,0);
    }

    function testBorrowAndRebalanceWithMarginError() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);

        uint256[] memory ratio = new uint256[](2);
        ratio[0] = reserve0 * 20;
        ratio[1] = reserve1 * 210; // Margin error

        uint256 desiredRatio = ratio[1] * 1e18 / ratio[0];
        assertGt(desiredRatio,price);

        vm.expectRevert(bytes4(keccak256("Margin()")));
        pool.borrowLiquidity(tokenId, lpTokens/4, ratio);
    }

    function testFailBorrowAndRebalanceWrongRatio() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        uint128[] memory collateral = pool.increaseCollateral(tokenId);

        uint256[] memory ratio = new uint256[](1);
        ratio[0] = reserve0 * 3;
        //ratio[1] = reserve1 * 2; // Margin error
        //ratio[2] = 210000;

        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, ratio);


        vm.stopPrank();
    }

    function testFailBorrowAndRebalanceWrongRatio2() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        uint128[] memory collateral = pool.increaseCollateral(tokenId);

        uint256[] memory ratio = new uint256[](2);
        ratio[0] = reserve0 * 3;
        //ratio[1] = reserve1 * 2; // Margin error
        //ratio[2] = 210000;

        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, ratio);


        vm.stopPrank();
    }

    function testFailBorrowAndRebalanceWrongRatio3() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        uint128[] memory collateral = pool.increaseCollateral(tokenId);

        uint256[] memory ratio = new uint256[](2);
        ratio[1] = reserve0 * 3;
        //ratio[1] = reserve1 * 2; // Margin error
        //ratio[2] = 210000;

        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, ratio);


        vm.stopPrank();
    }

    function testLowerStrikePx() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        uint128[] memory collateral = pool.increaseCollateral(tokenId);

        uint256[] memory ratio = new uint256[](2);
        ratio[0] = reserve0 * 3;
        ratio[1] = reserve1 * 2;

        uint256 desiredRatio = ratio[1] * 1e18 / ratio[0];
        assertLt(desiredRatio,price);

        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, ratio);

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];

        vm.stopPrank();
        assertEq(strikePx/1e9,desiredRatio/1e9);
    }

    function testHigherStrikePx() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        uint128[] memory collateral = pool.increaseCollateral(tokenId);

        uint256[] memory ratio = new uint256[](2);
        ratio[0] = reserve0 * 2;
        ratio[1] = reserve1 * 3;

        uint256 desiredRatio = ratio[1] * 1e18 / ratio[0];
        assertGt(desiredRatio,price);

        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, ratio);

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];

        vm.stopPrank();
        assertEq(strikePx/1e9,desiredRatio/1e9); // will be off slightly because of different reserve quantities
    }

    function testPxUpCloseFullToken0() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        usdc.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(usdc), address(weth), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertGt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity, new uint256[](0), 1, addr1);
        assertEq(liquidityPaid, loanData.liquidity);

        loanData = pool.loan(tokenId);
        assertEq(loanData.tokensHeld[0],0);
        assertEq(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxUpCloseFullToken1() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        usdc.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(usdc), address(weth), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertGt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity, new uint256[](0), 2, addr1);
        assertEq(liquidityPaid, loanData.liquidity);

        loanData = pool.loan(tokenId);
        assertEq(loanData.tokensHeld[0],0);
        assertEq(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxUpCloseHalfToken0() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        usdc.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(usdc), address(weth), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertGt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity/2, new uint256[](0), 1, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/2)/1e9);

        loanData = pool.loan(tokenId);
        assertGt(loanData.tokensHeld[0],0);
        assertGt(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxUpCloseHalfToken1() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        usdc.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(usdc), address(weth), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertGt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity/2, new uint256[](0), 2, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/2)/1e9);

        loanData = pool.loan(tokenId);
        assertGt(loanData.tokensHeld[0],0);
        assertGt(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxDownCloseFullToken0() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        weth.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(weth), address(usdc), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertLt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity, new uint256[](0), 1, addr1);
        assertEq(liquidityPaid, loanData.liquidity);

        loanData = pool.loan(tokenId);
        assertEq(loanData.tokensHeld[0],0);
        assertEq(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxDownCloseFullToken1() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        weth.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(weth), address(usdc), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertLt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity, new uint256[](0), 2, addr1);
        assertEq(liquidityPaid, loanData.liquidity);

        loanData = pool.loan(tokenId);
        assertEq(loanData.tokensHeld[0],0);
        assertEq(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxDownCloseHalfToken0() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        weth.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(weth), address(usdc), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertLt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity/2, new uint256[](0), 1, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/2)/1e9);

        loanData = pool.loan(tokenId);
        assertGt(loanData.tokensHeld[0],0);
        assertGt(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxDownCloseHalfToken1() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        weth.mint(addr1, 100 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  100 * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(weth), address(usdc), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertLt(price1,price);

        uint256 liquidityPaid;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity/2, new uint256[](0), 2, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/2)/1e9);

        loanData = pool.loan(tokenId);
        assertGt(loanData.tokensHeld[0],0);
        assertGt(loanData.tokensHeld[1],0);

        uint256 usdcBal1 = usdc.balanceOf(addr1);
        uint256 wethBal1 = weth.balanceOf(addr1);
        assertGt(usdcBal1, usdcBal0);
        assertGt(wethBal1, wethBal0);

        vm.stopPrank();
    }

    function testPxDownCloseToken0(uint8 _amountIn, uint8 _liquidityDiv) public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        assertGt(IERC20(cfmm).totalSupply(), 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        weth.mint(addr1, 1000 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        {
            (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

            assertGt(liquidityBorrowed, 0);
            assertGt(amounts[0], 0);
            assertGt(amounts[1], 0);
        }

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  (uint256(_amountIn) + 1) * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(weth), address(usdc), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertLt(price1,price);

        uint256[] memory fees = new uint256[](2);
        fees[0] = 0;
        fees[1] = _amountIn > 100 ? 1 : 0; // adding a bit more otherwise if price changed too much we get MinBorrow error

        uint256 liquidityPaid;
        uint256 liquidityDiv = uint256(_liquidityDiv) + 1;
        (liquidityPaid,) = pool.repayLiquidity(tokenId, loanData.liquidity/liquidityDiv, fees, 1, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/liquidityDiv)/1e9);

        loanData = pool.loan(tokenId);
        if(liquidityDiv == 1) {
            assertEq(loanData.tokensHeld[0],0);
            if(fees[1] > 0) {
                assertGt(loanData.tokensHeld[1],0);
            } else {
                assertEq(loanData.tokensHeld[1],0);
            }
        } else {
            assertGt(loanData.tokensHeld[0],0);
            assertGt(loanData.tokensHeld[1],0);
        }

        assertGt(usdc.balanceOf(addr1), usdcBal0);
        assertGt(weth.balanceOf(addr1), wethBal0);

        vm.stopPrank();
    }

    function testPxDownCloseToken1(uint8 _amountIn, uint8 _liquidityDiv) public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        assertGt(IERC20(cfmm).totalSupply(), 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        weth.mint(addr1, 1000 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  (uint256(_amountIn) + 1) * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(weth), address(usdc), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertLt(price1,price);

        uint256 liquidityPaid;
        uint256 liquidityDiv = uint256(_liquidityDiv) + 1;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity/liquidityDiv, new uint256[](0), 2, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/liquidityDiv)/1e9);

        loanData = pool.loan(tokenId);
        if(liquidityDiv == 1) {
            assertEq(loanData.tokensHeld[0],0);
            assertEq(loanData.tokensHeld[1],0);
        } else {
            assertGt(loanData.tokensHeld[0],0);
            assertGt(loanData.tokensHeld[1],0);
        }

        assertGt(usdc.balanceOf(addr1), usdcBal0);
        assertGt(weth.balanceOf(addr1), wethBal0);

        vm.stopPrank();
    }

    function testPxUpCloseToken0(uint8 _amountIn, uint8 _liquidityDiv) public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        assertGt(IERC20(cfmm).totalSupply(), 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        usdc.mint(addr1, 1000 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  (uint256(_amountIn) + 1) * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(usdc), address(weth), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price1, 0);
        assertGt(price1,price);

        uint256 liquidityPaid;
        uint256 liquidityDiv = uint256(_liquidityDiv) + 1;
        (liquidityPaid, amounts) = pool.repayLiquidity(tokenId, loanData.liquidity/liquidityDiv, new uint256[](0), 1, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/liquidityDiv)/1e9);

        loanData = pool.loan(tokenId);
        if(liquidityDiv == 1) {
            assertEq(loanData.tokensHeld[0],0);
            assertEq(loanData.tokensHeld[1],0);
        } else {
            assertGt(loanData.tokensHeld[0],0);
            assertGt(loanData.tokensHeld[1],0);
        }

        assertGt(usdc.balanceOf(addr1), usdcBal0);
        assertGt(weth.balanceOf(addr1), wethBal0);

        vm.stopPrank();
    }

    function testPxUpCloseToken1(uint8 _amountIn, uint8 _liquidityDiv) public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        assertGt(IERC20(cfmm).totalSupply(), 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        usdc.mint(addr1, 1000 * 1_000_000 * 1e18);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 200_000 * 1e18);
        weth.transfer(address(pool), 200 * 1e18);

        pool.increaseCollateral(tokenId);
        {
            (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

            assertGt(liquidityBorrowed, 0);
            assertGt(amounts[0], 0);
            assertGt(amounts[1], 0);
        }

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256 strikePx = uint256(loanData.tokensHeld[1]) * 1e18 / loanData.tokensHeld[0];
        assertEq(strikePx/1e9,price/1e9);

        uint256 amountIn =  (uint256(_amountIn) + 1) * 1_000_000 * 1e18;
        sellTokenIn(amountIn, address(usdc), address(weth), addr1);
        uint256 usdcBal0 = usdc.balanceOf(addr1);
        uint256 wethBal0 = weth.balanceOf(addr1);


        (reserve0, reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        {
            uint256 price1 = uint256(reserve1) * (1e18) / reserve0;
            assertGt(price1, 0);
            assertGt(price1,price);
        }

        uint256 liquidityPaid;
        uint256 liquidityDiv = uint256(_liquidityDiv) + 1;
        uint256[] memory fees = new uint256[](2);
        fees[0] = _amountIn > 100 ? 1 : 0; // adding a bit more otherwise if price changed too much we get MinBorrow error
        fees[1] = 0;
        (liquidityPaid,) = pool.repayLiquidity(tokenId, loanData.liquidity/liquidityDiv, fees, 2, addr1);
        assertEq(liquidityPaid/1e9, (loanData.liquidity/liquidityDiv)/1e9);

        loanData = pool.loan(tokenId);
        if(liquidityDiv == 1) {
            if(fees[0] > 0) {
                assertGt(loanData.tokensHeld[0],0);
            } else {
                assertEq(loanData.tokensHeld[0],0);
            }
            assertEq(loanData.tokensHeld[1],0);
        } else {
            assertGt(loanData.tokensHeld[0],0);
            assertGt(loanData.tokensHeld[1],0);
        }

        assertGt(usdc.balanceOf(addr1), usdcBal0);
        assertGt(weth.balanceOf(addr1), wethBal0);

        vm.stopPrank();
    }

    function testRebalanceBuyCollateral(uint256 collateralId, int256 amount) public {
        collateralId = bound(collateralId, 0, 1);
        if (collateralId == 0) {    // if WETH rebalance
            amount = bound(amount, 1e16, 100*1e18);
        } else {    // if USDC rebalance
            amount = bound(amount, 10*1e18, 1_000_000*1e18);
        }
        if (amount == 0) return;

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        uint128[] memory tokensHeldBefore = new uint128[](2);
        tokensHeldBefore[0] = 2000 * 1e18;
        tokensHeldBefore[1] = 2_000_000 * 1e18;

        weth.transfer(address(pool), tokensHeldBefore[0]);
        usdc.transfer(address(pool), tokensHeldBefore[1]);

        pool.increaseCollateral(tokenId);

        int256[] memory deltas = new int256[](2);
        deltas[collateralId] = amount;
        deltas[1 - collateralId] = 0;

        uint128[] memory tokensHeldAfter = pool.rebalanceCollateral(tokenId, deltas, new uint256[](0));
        assertEq(tokensHeldAfter[collateralId], tokensHeldBefore[collateralId] + uint256(amount));
    }

    function testRebalanceSellCollateral(uint256 collateralId, int256 amount) public {
        collateralId = bound(collateralId, 0, 1);
        if (collateralId == 0) {    // if WETH rebalance
            amount = bound(amount, 1e16, 100*1e18);
        } else {    // if USDC rebalance
            amount = bound(amount, 10*1e18, 1_000_000*1e18);
        }
        if (amount == 0) return;

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        uint128[] memory tokensHeldBefore = new uint128[](2);
        tokensHeldBefore[0] = 2000 * 1e18;
        tokensHeldBefore[1] = 2_000_000 * 1e18;

        weth.transfer(address(pool), tokensHeldBefore[0]);
        usdc.transfer(address(pool), tokensHeldBefore[1]);

        pool.increaseCollateral(tokenId);

        int256[] memory deltas = new int256[](2);
        deltas[collateralId] = -amount;
        deltas[1 - collateralId] = 0;

        uint128[] memory tokensHeldAfter = pool.rebalanceCollateral(tokenId, deltas, new uint256[](0));
        assertEq(tokensHeldAfter[collateralId], tokensHeldBefore[collateralId] - uint256(amount));
    }

    function testRebalanceWithRatio(uint256 r0, uint256 r1) public {
        r0 = bound(r0, 1, 100);
        r1 = bound(r1, 1, 100);

        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();
        uint256[] memory ratio = new uint256[](2);
        ratio[0] = reserve0 * r0;
        ratio[1] = reserve1 * r1;
        uint256 desiredRatio = ratio[1] * 1e18 / ratio[0];

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        uint128[] memory tokensHeldBefore = new uint128[](2);
        tokensHeldBefore[0] = 200 * 1e18;
        tokensHeldBefore[1] = 200_000 * 1e18;

        weth.transfer(address(pool), tokensHeldBefore[0]);
        usdc.transfer(address(pool), tokensHeldBefore[1]);

        pool.increaseCollateral(tokenId);

        if (r0 == r1) {
            vm.expectRevert(bytes4(keccak256("BadDelta()")));
            pool.rebalanceCollateral(tokenId, new int256[](0), ratio);
            return;
        }
        uint128[] memory tokensHeldAfter = pool.rebalanceCollateral(tokenId, new int256[](0), ratio);
        assertEq((tokensHeldAfter[0] * desiredRatio / 1e18) / 1e15, tokensHeldAfter[1] / 1e15); // Precision of 3 decimals, good enough
    }

    function testRebalanceMarginError() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();
        uint256[] memory ratio = new uint256[](2);
        ratio[0] = reserve0 * 200;
        ratio[1] = reserve1 * 10;

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        weth.transfer(address(pool), 1000 * 1e18);
        usdc.transfer(address(pool), 1_000_000 * 1e18);

        pool.increaseCollateral(tokenId);

        uint256 lpTokens = IERC20(cfmm).totalSupply();
        pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        vm.expectRevert(bytes4(keccak256("Margin()")));
        pool.rebalanceCollateral(tokenId, new int256[](0), ratio);
    }

    function testRepayLiquidityWrongCollateral(uint256 collateralId) public {
        collateralId = bound(collateralId, 3, 1000);
        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        weth.transfer(address(pool), 200 * 1e18);
        usdc.transfer(address(pool), 200_000 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        vm.expectRevert();
        pool.repayLiquidity(tokenId, loanData.liquidity, new uint256[](0), collateralId, address(0));
    }

    /// @dev Try to repay loan debt with huge fees
    function testRepayLiquidityBadDebt() public {
        (uint128 reserve0, uint128 reserve1,) = IUniswapV2Pair(cfmm).getReserves();

        uint256 price = uint256(reserve1) * (1e18) / reserve0;
        assertGt(price, 0);

        uint256 totalSupply = IERC20(cfmm).totalSupply();
        assertGt(totalSupply, 0);

        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 150_000 * 1e18);
        weth.transfer(address(pool), 150 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed, uint256[] memory amounts) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        assertGt(liquidityBorrowed, 0);
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, 0);

        uint256[] memory fees = new uint256[](2);
        fees[0] = 5000;
        fees[1] = 5000;

        vm.expectRevert(bytes4(keccak256("NotEnoughBalance()")));
        pool.repayLiquidity(tokenId, loanData.liquidity, fees, 1, addr1);
    }

    /// @dev Loan debt increases as time passes
    function testLoanDebtIncrease() public {
        uint256 lpTokens = IERC20(cfmm).balanceOf(address(pool));
        assertGt(lpTokens, 0);

        vm.startPrank(addr1);
        uint256 tokenId = pool.createLoan();
        assertGt(tokenId, 0);

        usdc.transfer(address(pool), 130_000 * 1e18);
        weth.transfer(address(pool), 130 * 1e18);

        pool.increaseCollateral(tokenId);
        (uint256 liquidityBorrowed,) = pool.borrowLiquidity(tokenId, lpTokens/4, new uint256[](0));

        IGammaPool.LoanData memory loanData = pool.loan(tokenId);
        assertEq(loanData.liquidity, liquidityBorrowed);

        vm.roll(100000000);  // After a while

        loanData = pool.loan(tokenId);
        assertGt(loanData.liquidity, liquidityBorrowed);

        vm.expectRevert(bytes4(keccak256("NotEnoughBalance()")));
        pool.repayLiquidity(tokenId, loanData.liquidity, new uint256[](0), 2, addr1);
    }
}
