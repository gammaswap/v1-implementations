// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../cpmm/CPMMShortStrategy.sol";
import "./base/VaultBaseStrategy.sol";
import "../../interfaces/vault/strategies/IVaultShortStrategy.sol";

/// @title Vault Short Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by ShortStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract VaultShortStrategy is CPMMShortStrategy, VaultBaseStrategy, IVaultShortStrategy {

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

    /// @dev See {IVaultShortStrategy-totalReservedAssetsAndSupply}.
    function totalReservedAssetsAndSupply(IVaultShortStrategy.VaultReservedBalancesParams memory _params) external virtual override view returns(uint256 assets, uint256 supply) {
        // use lastFeeIndex and cfmmFeeIndex to hold maxCFMMFeeLeverage and spread respectively
        (uint256 borrowRate, uint256 utilizationRate, uint256 lastFeeIndex, uint256 cfmmFeeIndex) = calcBorrowRate(_params.LP_INVARIANT,
            _params.BORROWED_INVARIANT, _params.paramsStore, _params.pool);

        (lastFeeIndex, cfmmFeeIndex) = getLastFees(borrowRate, _params.BORROWED_INVARIANT, _params.latestCfmmInvariant,
            _params.latestCfmmTotalSupply, _params.lastCFMMInvariant, _params.lastCFMMTotalSupply, _params.LAST_BLOCK_NUMBER,
            _params.lastCFMMFeeIndex, lastFeeIndex, cfmmFeeIndex);

        _params.RESERVED_BORROWED_INVARIANT = GSMath.min(_params.RESERVED_BORROWED_INVARIANT, _params.BORROWED_INVARIANT);
        unchecked {
            _params.BORROWED_INVARIANT = _params.BORROWED_INVARIANT - _params.RESERVED_BORROWED_INVARIANT;
        }
        // Total amount of GS LP tokens issued after protocol fees are paid
        assets = totalAssets(_params.BORROWED_INVARIANT, _params.LP_TOKEN_BALANCE +
            convertInvariantToLP(_params.RESERVED_BORROWED_INVARIANT, _params.lastCFMMTotalSupply, _params.lastCFMMInvariant),
            _params.latestCfmmInvariant, _params.latestCfmmTotalSupply, lastFeeIndex);

        // Calculates total CFMM LP tokens, including accrued interest, using state variables
        supply = totalSupply(_params.factory, _params.pool, cfmmFeeIndex, lastFeeIndex, utilizationRate, _params.totalSupply);
    }

    /// @dev See {IShortStrategy-totalAssetsAndSupply}.
    function totalAssetsAndSupply(VaultBalancesParams memory _params) public virtual override view returns(uint256 assets, uint256 supply) {
        return (0,0);
    }

    /// @inheritdoc IShortStrategy
    function getLatestBalances(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lpBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual override view
        returns(uint256 lastLPBalance, uint256 lastBorrowedLPBalance, uint256 lastBorrowedInvariant) {
        lastBorrowedInvariant = _accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
        lastBorrowedLPBalance =  convertInvariantToLP(lastBorrowedInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
        lastLPBalance = lpBalance + lastBorrowedLPBalance;
    }
}
