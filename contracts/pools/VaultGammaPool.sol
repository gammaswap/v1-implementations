// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../interfaces/vault/strategies/IVaultReserveStrategy.sol";
import "../interfaces/vault/strategies/IVaultShortStrategy.sol";
import "../interfaces/vault/IVaultGammaPool.sol";
import "./CPMMGammaPool.sol";

/// @title Vault GammaPool implementation for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev This implementation is specifically for validating UniswapV2Pair and clone contracts
contract VaultGammaPool is CPMMGammaPool, IVaultGammaPool {

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `borrowStrategy`, `repayStrategy`,
    /// @dev `shortStrategy`, `liquidationStrategy`, `batchLiquidationStrategy`, `cfmmFactory`, and `cfmmInitCodeHash`.
    constructor(uint16 _protocolId, address _factory, address _borrowStrategy, address _repayStrategy,
        address _shortStrategy, address _liquidationStrategy, address _batchLiquidationStrategy, address _viewer,
        address _externalRebalanceStrategy, address _externalLiquidationStrategy, address _cfmmFactory,
        bytes32 _cfmmInitCodeHash) CPMMGammaPool(_protocolId, _factory, _borrowStrategy, _repayStrategy,
        _shortStrategy, _liquidationStrategy, _batchLiquidationStrategy, _viewer, _externalRebalanceStrategy,
        _externalLiquidationStrategy, _cfmmFactory, _cfmmInitCodeHash) {
    }

    /// @dev See {IVaultGammaPool-reserveLPTokens}
    function reserveLPTokens(uint256 tokenId, uint256 lpTokens, bool isReserve) external virtual override whenNotPaused(26) returns(uint256) {
        return abi.decode(callStrategy(externalRebalanceStrategy, abi.encodeCall(IVaultReserveStrategy._reserveLPTokens, (tokenId, lpTokens, isReserve))), (uint256));
    }

    /// @dev See {IVaultGammaPool-getReservedBalances}
    function getReservedBalances() external virtual override view returns(uint256 reservedBorrowedInvariant, uint256 reservedLPTokens) {
        reservedBorrowedInvariant = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_BORROWED_INVARIANT));
        reservedLPTokens = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));
    }

    /// @dev See {IGammaPool-repayLiquidityWithLP}
    function repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external virtual override whenNotPaused(15) returns(uint256, uint128[] memory) {
        return (0, new uint128[](0));
    }

    /// @dev See {IGammaPoolExternal-liquidateExternally}
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual whenNotPaused(25) returns(uint256, uint256[] memory) {
        return (0, new uint256[](0));
    }

    /// @dev See {GammaPoolERC4626-maxAssets}
    function maxAssets(uint256 assets) internal view virtual override returns(uint256) {
        uint256 reservedLpTokenBalance = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE; // CFMM LP tokens in GammaPool that have not been borrowed
        lpTokenBalance = lpTokenBalance - GSMath.min(reservedLpTokenBalance, lpTokenBalance);
        if(assets < lpTokenBalance){ // limit assets available to withdraw to what has not been borrowed
            return assets;
        }
        return lpTokenBalance;
    }

    /// @dev See {GammaPoolERC4626-_totalAssetsAndSupply}
    function _totalAssetsAndSupply() internal view virtual override returns (uint256 assets, uint256 supply) {
        address _factory = s.factory;
        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        uint256 reservedBorrowedInvariant = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_BORROWED_INVARIANT));
        (assets, supply) = IVaultShortStrategy(vaultImplementation()).totalAssetsAndSupply(
            IVaultShortStrategy.VaultReservedBalancesParams({
                factory: _factory,
                pool: address(this),
                paramsStore: _factory,
                BORROWED_INVARIANT: borrowedInvariant,
                RESERVED_BORROWED_INVARIANT: reservedBorrowedInvariant,
                latestCfmmInvariant: _getLatestCFMMInvariant(),
                latestCfmmTotalSupply: _getLatestCFMMTotalSupply(),
                LAST_BLOCK_NUMBER: s.LAST_BLOCK_NUMBER,
                lastCFMMInvariant: s.lastCFMMInvariant,
                lastCFMMTotalSupply: s.lastCFMMTotalSupply,
                lastCFMMFeeIndex: s.lastCFMMFeeIndex,
                totalSupply: s.totalSupply,
                LP_TOKEN_BALANCE: s.LP_TOKEN_BALANCE,
                LP_INVARIANT: s.LP_INVARIANT
            })
        );
    }
}
