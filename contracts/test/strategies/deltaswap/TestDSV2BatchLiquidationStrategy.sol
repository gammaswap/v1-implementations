// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/base/BaseBorrowStrategy.sol";
import "../../../strategies/deltaswap/liquidation/DSV2BatchLiquidationStrategy.sol";

contract TestDSV2BatchLiquidationStrategy is DSV2BatchLiquidationStrategy, BaseBorrowStrategy {

    using LibStorage for LibStorage.Storage;
    using GSMath for uint;
    error ExcessiveBorrowing();

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor(address liquidator_, address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_,
        uint24 tradingFee2_, address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_)
        DSV2BatchLiquidationStrategy(liquidator_, mathLib_, maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_,
        feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    function initialize(address factory_, address cfmm_, address[] calldata tokens_, uint8[] calldata decimals_) external virtual {
        s.initialize(factory_, cfmm_, 1, tokens_, decimals_, 1e3);
    }

    function cfmm() public view returns(address) {
        return s.cfmm;
    }

    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);
        emit LoanCreated(msg.sender, tokenId);
    }

    function getLoan(uint256 tokenId) external virtual view returns(LibStorage.Loan memory _loan) {
        _loan = s.loans[tokenId];
    }

    function getPoolData() external virtual view returns(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lpTokenBorrowedPlusInterest,
        uint128 borrowedInvariant, uint128 lpInvariant, uint128 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint128[] memory tokenBalance,
        uint48 lastBlockNumber, uint96 accFeeIndex) {
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        lpTokenBorrowed = s.LP_TOKEN_BORROWED;
        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        borrowedInvariant = s.BORROWED_INVARIANT;
        lpInvariant = s.LP_INVARIANT;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        tokenBalance = s.TOKEN_BALANCE;
        lastBlockNumber = s.LAST_BLOCK_NUMBER;
        accFeeIndex = s.accFeeIndex;
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
        amounts = calcTokensToRepay(s.CFMM_RESERVES, liquidity, new uint128[](0), true);
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
        uint256 actualOutAmount = calcActualOutAmt(token, to, amount, balance, collateral);
        emit ActualOutAmount(actualOutAmount);
    }

    function testBeforeSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (outAmts, inAmts) = beforeSwapTokens(loan, deltas, s.CFMM_RESERVES);
        emit CalcAmounts(outAmts, inAmts);
    }

    function testSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(loan, deltas, s.CFMM_RESERVES);
        swapTokens(loan, outAmts, inAmts);
        emit CalcAmounts(outAmts, inAmts);
    }

    function depositLPTokens(uint256 tokenId) external virtual {
        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        updateIndex();
        updateCollateral(s.loans[tokenId]);
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
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

    function calcBorrowRate(uint256, uint256, address, address) public override(AbstractRateModel, LinearKinkedRateModel) virtual view returns(uint256,uint256,uint256,uint256) {
        return (1e19,1e19,5000,1e18);
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external virtual returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
        // Revert if borrowing all CFMM LP tokens in pool
        if(lpTokens >= s.LP_TOKEN_BALANCE) revert ExcessiveBorrowing();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Withdraw reserve tokens from CFMM that lpTokens represent
        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        // Add withdrawn tokens as part of loan collateral
        (uint128[] memory tokensHeld,) = updateCollateral(_loan);

        // Add liquidity debt to total pool debt and start tracking loan
        (liquidityBorrowed, loanLiquidity) = openLoan(_loan, lpTokens);

        // Check that loan is not undercollateralized
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkLoanMargin(collateral, loanLiquidity);
    }

    function updateLoanPrice(uint256, uint256, uint256, uint256) internal override virtual view returns(uint256) {
    }

    function checkLoanMargin(uint256 collateral, uint256 liquidity) internal virtual view {
        if(!hasMargin(collateral, liquidity, _ltvThreshold())) revert HasMargin(); // Revert if loan does not have enough collateral
    }

    /// @dev See {BaseLongStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

    function validateParameters(bytes calldata _data) external override(IRateModel, LinearKinkedRateModel) virtual view returns(bool) {
        return true;
    }

    function getRateModelParams(address paramsStore, address pool) public virtual override view returns(uint64, uint64, uint64, uint64) {
        return (baseRate, optimalUtilRate, slope1, slope2);
    }

    function _calcOriginationFee(uint256 liquidityBorrowed, uint256 borrowedInvariant, uint256 lpInvariant, uint256 lowUtilRate, uint256 discount) internal override virtual view returns(uint256 origFee) {
        return 0;
    }

    function _calcDynamicOriginationFee(uint256 baseOrigFee, uint256 utilRate, uint256 lowUtilRate, uint256 minUtilRate1, uint256 minUtilRate2, uint256 feeDivisor) internal virtual override view returns(uint256) {
        return 0;
    }

    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override view {
    }

    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity, uint128[] memory maxAmounts, bool isLiquidation) internal virtual override(BaseLongStrategy,CPMMBaseLongStrategy) view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = calcInvariant(address(0), reserves);

        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 expectedLPTokens = liquidity * lastCFMMTotalSupply / lastCFMMInvariant;

        amounts[0] = expectedLPTokens * reserves[0] / lastCFMMTotalSupply + 1;
        amounts[1] = expectedLPTokens * reserves[1] / lastCFMMTotalSupply + 1;

        if(maxAmounts.length == 2) {
            amounts[0] = GSMath.min(amounts[0], maxAmounts[0]);
            amounts[1] = GSMath.min(amounts[1], maxAmounts[1]);
        }
    }
}
