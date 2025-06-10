// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/rebalance/ExternalRebalanceStrategy.sol";
import "../../../interfaces/vault/strategies/IVaultReserveStrategy.sol";
import "../base/VaultBaseLongStrategy.sol";

/// @title Vault External Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with UniswapV2
contract VaultExternalRebalanceStrategy is VaultBaseLongStrategy, ExternalRebalanceStrategy, IVaultReserveStrategy {

    error InvalidRefType();
    error ExcessiveLPTokensReserved();

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_, address feeSource_,
        uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseLongStrategy(maxTotalApy_,
        blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseStrategy-accrueBorrowedInvariant}.
    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual
        override(BaseStrategy,VaultBaseLongStrategy) view returns(uint256) {
        return super.accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
    }

    /// @dev Update loan's liquidity debt with interest charged except when loan is of refType 3
    /// @dev See {BaseLongStrategy-updateLoanLiquidity}.
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual
        override(BaseLongStrategy,VaultBaseLongStrategy) returns(uint256 liquidity) {
        return super.updateLoanLiquidity(_loan, accFeeIndex);
    }

    /// @dev See {BaseStrategy-checkExpectedUtilizationRate}.
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override(BaseStrategy,VaultBaseLongStrategy) view {
        return super.checkExpectedUtilizationRate(lpTokens, isLoan);
    }

    /// @dev See {IVaultStrategy-_reserveLPTokens}.
    function _reserveLPTokens(uint256 tokenId, uint256 lpTokens, bool isReserve) external virtual override lock returns(uint256) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        if(_loan.refType != 3) revert InvalidRefType();

        updateLoan(_loan);

        uint256 key = RESERVED_LP_TOKENS();
        if(isReserve) {
            uint256 lpTokenBalance = getAdjLPTokenBalance();

            // Revert if reserving all remaining CFMM LP tokens in pool
            if(lpTokens >= lpTokenBalance) revert ExcessiveLPTokensReserved();

            checkExpectedUtilizationRate(lpTokens, true);

            s.setUint256(key, s.getUint256(key) + lpTokens);
        } else {
            uint256 reservedLPTokens = s.getUint256(key);

            lpTokens = GSMath.min(reservedLPTokens, lpTokens);
            unchecked {
                reservedLPTokens = reservedLPTokens - lpTokens;
            }

            s.setUint256(key, reservedLPTokens);
        }

        return lpTokens;
    }

    /// @dev See {IExternalLongStrategy-_rebalanceExternally}.
    function _rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override lock virtual returns(uint256 loanLiquidity, uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        loanLiquidity = updateLoan(_loan);

        address _cfmm = s.cfmm;

        uint256 liquiditySwapped;
        // Calculate amounts to swap from deltas and available loan collateral
        (liquiditySwapped, tokensHeld) = externalSwap(_loan, _cfmm, amounts, lpTokens, to, data);
        _loan.tokensHeld = tokensHeld;

        if(liquiditySwapped > loanLiquidity && _loan.refType != 3) {
            uint256 fee = calcExternalSwapFee(liquiditySwapped, loanLiquidity);
            uint256 borrowedInvariant = s.BORROWED_INVARIANT + fee;
            s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
            s.BORROWED_INVARIANT = uint128(borrowedInvariant);
            loanLiquidity = loanLiquidity + fee;
            _loan.liquidity = uint128(loanLiquidity);
        }

        // Check that loan is not undercollateralized after external swap
        uint256 collateral = calcInvariant(_cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId);
        checkMargin(collateral, loanLiquidity);

        emit ExternalSwap(tokenId, amounts, lpTokens, uint128(liquiditySwapped), TX_TYPE.EXTERNAL_REBALANCE);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.EXTERNAL_REBALANCE);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.EXTERNAL_REBALANCE);
    }
}
