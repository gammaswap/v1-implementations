// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/cpmm/CPMMLiquidationStrategy.sol";

contract TestCPMMLiquidationStrategy is CPMMLiquidationStrategy {

    using LibStorage for LibStorage.Storage;
    using Math for uint;
    error ExcessiveBorrowing();

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor(uint16 _liquidationThreshold, uint16 _liquidationFeeThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMLiquidationStrategy(_liquidationThreshold, _liquidationFeeThreshold, _maxTotalApy, _blocksPerYear, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    function initialize(address _factory, address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        s.initialize(_factory, _cfmm, _tokens, _decimals);
    }

    function cfmm() public view returns(address) {
        return s.cfmm;
    }

    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        emit LoanCreated(msg.sender, tokenId);
    }

    function getLoan(uint256 tokenId) external virtual view returns(LibStorage.Loan memory _loan) {
        _loan = s.loans[tokenId];
    }

    function setTokenBalances(uint256 tokenId, uint128 collateral0, uint128 collateral1, uint128 balance0, uint128 balance1) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        loan.tokensHeld[0] = collateral0;
        loan.tokensHeld[1] = collateral1;
        s.TOKEN_BALANCE[0] = balance0;
        s.TOKEN_BALANCE[1] = balance1;
    }

    function setCFMMReserves(uint128 reserve0, uint128 reserve1, uint128 lastCFMMInvariant) external virtual {
        s.CFMM_RESERVES[0] = reserve0;
        s.CFMM_RESERVES[1] = reserve1;
        s.lastCFMMInvariant = lastCFMMInvariant;
    }

    function testCalcTokensToRepay(uint256 liquidity) external virtual view returns(uint256, uint256) {
        uint256[] memory amounts;
        amounts = calcTokensToRepay(liquidity);
        return(amounts[0], amounts[1]);
    }

    function testBeforeRepay(uint256 tokenId, uint256[] memory amounts) external virtual {
        beforeRepay(s.loans[tokenId], amounts);
    }

    // selling exactly amountOut
    function testCalcAmtIn(uint256 amountOut, uint256 reserveOut, uint256 reserveIn) external virtual view returns (uint256) {
        return calcAmtIn(amountOut, reserveOut, reserveIn);
    }

    // buying exactly amountIn
    function testCalcAmtOut(uint256 amountIn, uint256 reserveOut, uint256 reserveIn) external virtual view returns (uint256) {
        return calcAmtOut(amountIn, reserveOut, reserveIn);
    }

    function testCalcActualOutAmount(address token, address to, uint256 amount, uint256 balance, uint256 collateral) external virtual {
        uint256 actualOutAmount = calcActualOutAmt(IERC20(token), to, amount, balance, collateral);
        emit ActualOutAmount(actualOutAmount);
    }

    function testBeforeSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (outAmts, inAmts) = beforeSwapTokens(loan, deltas);
        emit CalcAmounts(outAmts, inAmts);
    }

    function testSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(loan, deltas);
        swapTokens(loan, outAmts, inAmts);
        emit CalcAmounts(outAmts, inAmts);
    }

    function depositLPTokens(uint256 tokenId) external virtual {
        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        updateIndex();
        updateCollateral(s.loans[tokenId]);
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));
        uint128 lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.LP_INVARIANT = lpInvariant;
    }

    function getBalances() external virtual view returns(uint256 lpTokenBalance, uint256 lpInvariant) {
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        lpInvariant = s.LP_INVARIANT;
    }

    function updateLoanData(uint256 tokenId) external virtual {
        updateLoan(s.loans[tokenId]);
    }

    function calcBorrowRate(uint256, uint256) internal override virtual view returns(uint256) {
        return 1e19;
    }

    function canLiquidate(uint256 tokenId) external virtual view returns(bool) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        uint256 collateral = calcInvariant(s.cfmm, _loan.tokensHeld);
        return !hasMargin(collateral, _loan.liquidity, ltvThreshold());
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
        // Revert if borrowing all CFMM LP tokens in pool
        if(lpTokens >= s.LP_TOKEN_BALANCE) {
            revert ExcessiveBorrowing();
        }

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Withdraw reserve tokens from CFMM that lpTokens represent
        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        // Add withdrawn tokens as part of loan collateral
        uint128[] memory tokensHeld = updateCollateral(_loan);

        // Add liquidity debt to total pool debt and start tracking loan
        (liquidityBorrowed, loanLiquidity) = openLoan(_loan, lpTokens);

        // Check that loan is not undercollateralized
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkLoanMargin(collateral, loanLiquidity);
    }

    function checkLoanMargin(uint256 collateral, uint256 liquidity) internal virtual view {
        if(!hasMargin(collateral, liquidity, ltvThreshold())) { // Revert if loan does not have enough collateral
            revert HasMargin();
        }
    }
}