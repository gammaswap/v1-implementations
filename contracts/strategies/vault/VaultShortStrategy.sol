// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../cpmm/CPMMShortStrategy.sol";
import "./base/VaultBaseStrategy.sol";

/// @title Vault Short Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by ShortStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract VaultShortStrategy is CPMMShortStrategy, VaultBaseStrategy {

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_)
        CPMMShortStrategy(maxTotalApy_, blocksPerYear_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseStrategy-accrueBorrowedInvariant}.
    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual
        override(BaseStrategy,VaultBaseStrategy) view returns(uint256) {
        return super.accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
    }

    /// @dev See {BaseStrategy-checkExpectedUtilizationRate}.
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual override(BaseStrategy,VaultBaseStrategy) view {
        return super.checkExpectedUtilizationRate(lpTokens, isLoan);
    }

    /// @dev Excludes reserved LP tokens from available LP tokens to withdraw
    /// @dev See {ShortStrategy-withdrawAssetsNoPull}.
    function withdrawAssetsNoPull(address to, bool askForReserves) internal virtual override returns(uint256[] memory reserves, uint256 assets) {
        // Check is GammaPool has received GS LP tokens
        uint256 shares = s.balanceOf[address(this)];

        // Update interest rate and state variables before conversion
        updateIndex();

        // Convert GS LP tokens (`shares`) to CFMM LP tokens (`assets`)
        assets = convertToAssets(shares, false);
        // revert if request is for 0 CFMM LP tokens
        if(assets == 0) revert ZeroAssets();

        // Revert if not enough CFMM LP tokens in GammaPool
        if(assets > getAdjLPTokenBalance()) revert ExcessiveWithdrawal();

        // Send CFMM LP tokens or reserve tokens to receiver (`to`) and burn corresponding GS LP tokens from GammaPool address
        reserves = withdrawAssets(address(this), to, address(this), assets, shares, askForReserves);
    }

    /// @dev See {IShortStrategy-_withdraw}.
    function _withdraw(uint256 assets, address to, address from) external virtual override lock returns(uint256 shares) {
        // Update interest rate and state variables before conversion
        updateIndex();

        // Revert if not enough CFMM LP tokens to withdraw
        if(assets > getAdjLPTokenBalance()) revert ExcessiveWithdrawal();

        // Convert CFMM LP tokens to GS LP tokens
        shares = convertToShares(assets, true);

        // Revert if redeeming 0 GS LP tokens
        if(shares == 0) revert ZeroShares();

        // Send CFMM LP tokens to receiver (`to`) and burn corresponding GS LP tokens from msg.sender
        withdrawAssets(msg.sender, to, from, assets, shares, false);
    }

    /// @dev See {IShortStrategy-_redeem}.
    function _redeem(uint256 shares, address to, address from) external virtual override lock returns(uint256 assets) {
        // Update interest rate and state variables before conversion
        updateIndex();

        // Convert GS LP tokens to CFMM LP tokens
        assets = convertToAssets(shares, false);
        if(assets == 0) revert ZeroAssets(); // revert if withdrawing 0 CFMM LP tokens

        // Revert if not enough CFMM LP tokens to withdraw
        if(assets > getAdjLPTokenBalance()) revert ExcessiveWithdrawal();

        // Send CFMM LP tokens to receiver (`to`) and burn corresponding GS LP tokens from msg.sender
        withdrawAssets(msg.sender, to, from, assets, shares, false);
    }
}
