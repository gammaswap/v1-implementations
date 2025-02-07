// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/lending/BorrowStrategy.sol";
import "@gammaswap/v1-core/contracts/strategies/rebalance/RebalanceStrategy.sol";
import "../base/VaultBaseRebalanceStrategy.sol";

/// @title Vault Borrow and Rebalance Strategy concrete implementation contract for Vault GammaPool Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BorrowStrategy and RebalanceStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract VaultBorrowStrategy is VaultBaseRebalanceStrategy, BorrowStrategy, RebalanceStrategy {

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `mathLib`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_,
        address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseRebalanceStrategy(mathLib_,
        maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseBorrowStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

    /// @dev Update total interest charged except for reserved LP tokens
    /// @dev See {BaseStrategy-updateStore}.
    function updateStore(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply)
        internal virtual override(BaseStrategy,VaultBaseRebalanceStrategy) returns(uint256 accFeeIndex, uint256 newBorrowedInvariant) {
        return super.updateStore(lastFeeIndex, borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    /// @dev Update loan's liquidity debt with interest charged except when loan is of refType 3
    /// @dev See {BaseLongStrategy-updateLoanLiquidity}.
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual
        override(BaseLongStrategy,VaultBaseRebalanceStrategy) returns(uint256 liquidity) {
        return super.updateLoanLiquidity(_loan, accFeeIndex);
    }

    /// @dev Revert if lpTokens withdrawal causes utilization rate to go over 98%
    /// @param lpTokens - lpTokens expected to change utilization rate
    /// @param isRefType3 - true if loan borrowed is of refType 3
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isRefType3) internal virtual
        override(BaseStrategy,VaultBaseRebalanceStrategy) view {
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;

        uint256 lpInvariant = s.LP_INVARIANT;
        uint256 reservedLPInvariant = 0;
        if(!isRefType3) {
            reservedLPInvariant = convertLPToInvariant(s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS)),
                lastCFMMInvariant, lastCFMMTotalSupply);
            reservedLPInvariant = GSMath.min(lpInvariant, reservedLPInvariant);
            unchecked {
                lpInvariant = lpInvariant - reservedLPInvariant;
            }
        }

        uint256 lpTokenInvariant = convertLPToInvariant(lpTokens, lastCFMMInvariant, lastCFMMTotalSupply);
        if(lpInvariant < lpTokenInvariant) revert NotEnoughLPInvariant();
        unchecked {
            lpInvariant = lpInvariant - lpTokenInvariant;
        }
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + lpTokenInvariant + reservedLPInvariant;
        if(calcUtilizationRate(lpInvariant, borrowedInvariant) > 98e16) {
            revert MaxUtilizationRate();
        }
    }

    /// @dev See {IBorrowStrategy-_borrowLiquidity}.
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external virtual override lock returns(uint256 liquidityBorrowed, uint256[] memory amounts, uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        bool isRefType3 = _loan.refType == 3; // if refType3 include reserved LP tokens

        uint256 lpTokenBalance = isRefType3 ? s.LP_TOKEN_BALANCE : getAdjLPTokenBalance();

        // Revert if borrowing all CFMM LP tokens in pool
        if(lpTokens >= lpTokenBalance) revert ExcessiveBorrowing();

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        checkExpectedUtilizationRate(lpTokens, isRefType3);

        if(isRefType3) {
            uint256 reservedLPTokens = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));
            if(lpTokens >= reservedLPTokens) revert ExcessiveBorrowing();
            unchecked {
                reservedLPTokens = reservedLPTokens - lpTokens;
            }
            s.setUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS), reservedLPTokens);
        }

        // Withdraw reserve tokens from CFMM that lpTokens represent
        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        // Add withdrawn tokens as part of loan collateral
        (tokensHeld,) = updateCollateral(_loan);

        // Add liquidity debt to total pool debt and start tracking loan
        (liquidityBorrowed, loanLiquidity) = openLoan(_loan, lpTokens);

        if(isRefType3) {
            uint256 reservedBorrowedInvariant = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_BORROWED_INVARIANT));
            s.setUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_BORROWED_INVARIANT), reservedBorrowedInvariant + liquidityBorrowed);
        }

        if(isRatioValid(ratio)) {
            //get current reserves without updating
            uint128[] memory _reserves = getReserves(s.cfmm);
            int256[] memory deltas = _calcDeltasForRatio(tokensHeld, _reserves, ratio);
            if(isDeltasValid(deltas)) {
                (tokensHeld,) = rebalanceCollateral(_loan, deltas, _reserves);
            }
        }

        // Check that loan is not undercollateralized
        checkMargin(calcInvariant(s.cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId), loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.BORROW_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BORROW_LIQUIDITY);
    }
}
