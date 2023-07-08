// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/lending/BorrowStrategy.sol";
import "../../../strategies/cpmm/lending/CPMMRepayStrategy.sol";

contract TestCPMMRepayStrategy is CPMMRepayStrategy, BorrowStrategy {

    using LibStorage for LibStorage.Storage;

    event LoanCreated(address indexed caller, uint256 tokenId);

    constructor(address mathLib_, uint16 originationFee_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_, uint80 maxApy_)
        CPMMRepayStrategy(mathLib_, 8000, 1e19, 2252571, originationFee_, tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {
    }

    function initialize(address _factory, address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        s.initialize(_factory, _cfmm, 1, _tokens, _decimals);
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

        /*if(ratio.length > 0) {
            if(ratio.length != tokensHeld.length) revert InvalidRatioLength();
            //get current reserves without updating
            uint128[] memory _reserves = getReserves(s.cfmm);
            (tokensHeld,) = rebalanceCollateral(_loan, _calcDeltasForRatio(tokensHeld, _reserves, ratio), _reserves);
        }/**/

        // Check that loan is not undercollateralized
        checkMargin(calcInvariant(s.cfmm, tokensHeld), loanLiquidity);

        /*emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.BORROW_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BORROW_LIQUIDITY);/**/
    }

    function _decreaseCollateral(uint256, uint128[] calldata, address, uint256[] calldata) external virtual override returns(uint128[] memory collateral) {
    }

    function _increaseCollateral(uint256, uint256[] calldata) external virtual override returns(uint128[] memory collateral) {
    }

    function _repayLiquidityWithLP(uint256 tokenId, uint256 payLiquidity, uint256 collateralId, address to) external virtual override returns(uint256 liquidityPaid) {
        return 0;
    }

    function _repayLiquiditySetRatio(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256[] calldata ratio) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {
    }

    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal override(CPMMBaseRebalanceStrategy, BaseRebalanceStrategy) virtual view returns(int256[] memory deltas) {
    }

    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal override(CPMMBaseRebalanceStrategy, BaseRebalanceStrategy) virtual view returns(int256[] memory deltas) {
    }
}