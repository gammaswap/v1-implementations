// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/lending/BorrowStrategy.sol";
import "../../../strategies/cpmm/lending/CPMMRepayStrategy.sol";

contract TestCPMMRepayStrategy is CPMMRepayStrategy, BorrowStrategy {

    using LibStorage for LibStorage.Storage;

    event LoanCreated(address indexed caller, uint256 tokenId);

    constructor(address mathLib_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_, uint80 maxApy_)
        CPMMRepayStrategy(mathLib_, 1e19, 2252571, tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {
    }

    function initialize(address _factory, address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        s.initialize(_factory, _cfmm, 1, _tokens, _decimals);
        s.origFee = 0;
    }

    function _calcOriginationFee(uint256 liquidityBorrowed, uint256 borrowedInvariant, uint256 lpInvariant, uint256 lowUtilRate, uint256 discount) internal virtual override view returns(uint256 origFee) {
        origFee = originationFee();
        origFee = discount > origFee ? 0 : (origFee - discount);
    }

    function _calcDynamicOriginationFee(uint256 baseOrigFee, uint256 utilRate, uint256 lowUtilRate, uint256 minUtilRate, uint256 feeDivisor) internal virtual override view returns(uint256) {
        return baseOrigFee;
    }

    function testCalcTokensToRepay(uint256 liquidity) external virtual view returns(uint256, uint256) {
        uint256[] memory amounts = calcTokensToRepay(s.CFMM_RESERVES, liquidity);
        return(amounts[0], amounts[1]);
    }

    function testCalcInvariant(uint128[] calldata reserves) external virtual view returns(uint256) {
        return calcInvariant(address(0),reserves);
    }

    function testBeforeRepay(uint256 tokenId, uint256[] memory amounts) external virtual {
        beforeRepay(s.loans[tokenId], amounts);
    }

    function getLoan(uint256 tokenId) external virtual view returns(LibStorage.Loan memory _loan) {
        _loan = s.loans[tokenId];
    }

    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);
        emit LoanCreated(msg.sender, tokenId);
    }

    function depositLPTokens(uint256 tokenId) external virtual {
        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        updateIndex();
        updateCollateral(s.loans[tokenId]);
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        (s.LP_TOKEN_BALANCE, s.LP_INVARIANT) = (lpTokenBalance, uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply)));
    }

    function setTokenBalances(uint256 tokenId, uint128 collateral0, uint128 collateral1, uint128 balance0, uint128 balance1) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (loan.tokensHeld[0], loan.tokensHeld[1], s.TOKEN_BALANCE[0], s.TOKEN_BALANCE[1]) = (collateral0, collateral1, balance0, balance1);
    }

    function setCFMMReserves(uint128 reserve0, uint128 reserve1, uint128 lastCFMMInvariant) external virtual {
        (s.CFMM_RESERVES[0], s.CFMM_RESERVES[1], s.lastCFMMInvariant) = (reserve0, reserve1, lastCFMMInvariant);
    }

    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

    /// @dev See {IBorrowStrategy-_borrowLiquidity}.
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata) external virtual override returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
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
        checkMargin(calcInvariant(s.cfmm, tokensHeld), loanLiquidity);
    }

    function _decreaseCollateral(uint256, uint128[] calldata, address, uint256[] calldata) external virtual override returns(uint128[] memory collateral) {
    }

    function _increaseCollateral(uint256, uint256[] calldata) external virtual override returns(uint128[] memory collateral) {
    }

    function _repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external virtual override returns(uint256 liquidityPaid, uint128[] memory tokensHeld) {
    }

    function _repayLiquiditySetRatio(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256[] calldata ratio) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {
    }

    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal override(CPMMBaseRebalanceStrategy, BaseRebalanceStrategy) virtual view returns(int256[] memory deltas) {
    }

    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal override(CPMMBaseRebalanceStrategy, BaseRebalanceStrategy) virtual view returns(int256[] memory deltas) {
    }

    function updateLoanPrice(uint256 newLiquidity, uint256 currPrice, uint256 liquidity, uint256 lastPx) internal override virtual view returns(uint256) {
        return lastPx;
    }

    function onLoanUpdate(LibStorage.Loan storage _loan, uint256 tokenId) internal virtual override returns(uint256 externalCollateral) {
    }

    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex) internal virtual override {
    }

    function mintOrigFeeToDevs(uint256 origFeeInv, uint256 totalInvariant) internal virtual override {
    }
}