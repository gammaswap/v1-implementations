// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../cpmm/liquidation/CPMMExternalLiquidationStrategy.sol";
import "../base/VaultBaseLiquidationStrategy.sol";

/// @title Vault External Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice LiquidationStrategy implementation for Constant Product Market Maker that also allows external swaps (flash loans) during liquidations
/// @dev This implementation was specifically designed to work with UniswapV2
contract VaultExternalLiquidationStrategy is CPMMExternalLiquidationStrategy, VaultBaseLiquidationStrategy {

    /// @dev Initializes the contract by setting `liquidator`, `mathLib`,`MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `tradingFee1`, `tradingFee2`, `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address liquidator_, address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_,
        uint24 tradingFee2_, address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_)
        CPMMExternalLiquidationStrategy(liquidator_, mathLib_, maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_,
        feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseStrategy-accrueBorrowedInvariant}.
    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual
        override(BaseStrategy,VaultBaseLiquidationStrategy) view returns(uint256) {
        return super.accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
    }

    /// @dev Update loan's liquidity debt with interest charged except when loan is of refType 3
    /// @dev See {BaseLongStrategy-updateLoanLiquidity}.
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual
        override(BaseLongStrategy,VaultBaseLiquidationStrategy) returns(uint256 liquidity) {
        return super.updateLoanLiquidity(_loan, accFeeIndex);
    }

    /// @dev See {BaseStrategy-checkExpectedUtilizationRate}.
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override(BaseStrategy,VaultBaseLiquidationStrategy) view {
        return super.checkExpectedUtilizationRate(lpTokens, isLoan);
    }

    /// @dev See {BaseRepayStrategy-payLoanLiquidity}.
    function payLoanLiquidity(uint256 liquidity, uint256 loanLiquidity, LibStorage.Loan storage _loan) internal virtual
        override(BaseRepayStrategy,VaultBaseLiquidationStrategy) returns(uint256 lpTokenPrincipal, uint256 remainingLiquidity) {
        return super.payLoanLiquidity(liquidity, loanLiquidity, _loan);
    }

    /// @dev See {IExternalLiquidationStrategy-_liquidateExternally}.
    function _liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override lock beforeLiquidation virtual
        returns(uint256, uint128[] memory) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        (LiquidatableLoan memory _liqLoan,) = getLiquidatableLoan(_loan, tokenId);

        uint256 liquiditySwapped;
        (liquiditySwapped,) = externalSwap(_loan, s.cfmm, amounts, lpTokens, to, data); // of the CFMM LP Tokens that we pulled out, more have to come back

        for(uint256 i = 0; i < _liqLoan.tokensHeld.length;) {
            if(_liqLoan.tokensHeld[i] > _loan.tokensHeld[i]) revert CollateralShortfall();
            unchecked {
                ++i;
            }
        }

        uint256 loanLiquidity = _liqLoan.loanLiquidity;
        if(liquiditySwapped > loanLiquidity && _loan.refType != 3) {
            uint256 swapFee = calcExternalSwapFee(liquiditySwapped, loanLiquidity) / 2;
            uint256 borrowedInvariant = s.BORROWED_INVARIANT + swapFee;
            s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLPRoundUp(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
            s.BORROWED_INVARIANT = uint128(borrowedInvariant);
            loanLiquidity += swapFee;
            _loan.liquidity = uint128(loanLiquidity);
            _liqLoan.payableInternalLiquidity += swapFee;
            _liqLoan.loanLiquidity = loanLiquidity;
        }

        _liqLoan.writeDownAmt = payLiquidatableLoan(_liqLoan, 0, true);

        uint128[] memory refund;
        (refund, _liqLoan.tokensHeld) = refundLiquidator(_liqLoan.payableInternalLiquidityPlusFee, _liqLoan.internalCollateral, _liqLoan.tokensHeld);

        _loan.tokensHeld = _liqLoan.tokensHeld; // Clear loan collateral

        onLoanUpdate(_loan, tokenId);

        emit ExternalSwap(tokenId, amounts, lpTokens, uint128(liquiditySwapped), TX_TYPE.EXTERNAL_LIQUIDATION);

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(loanLiquidity - _liqLoan.writeDownAmt), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.internalFee), TX_TYPE.EXTERNAL_LIQUIDATION);

        emit LoanUpdated(tokenId, _liqLoan.tokensHeld, 0, 0, 0, 0, TX_TYPE.EXTERNAL_LIQUIDATION);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.EXTERNAL_LIQUIDATION);

        return(loanLiquidity, refund);
    }
}
