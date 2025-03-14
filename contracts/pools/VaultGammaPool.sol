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

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `borrowStrategy`, `repayStrategy`, `rebalanceStrategy`,
    /// @dev `shortStrategy`, `liquidationStrategy`, `batchLiquidationStrategy`, `cfmmFactory`, and `cfmmInitCodeHash`.
    constructor(InitializationParams memory params) CPMMGammaPool(params) {
    }

    /// @dev See {IVaultGammaPool-reserveLPTokens}
    function reserveLPTokens(uint256 tokenId, uint256 lpTokens, bool isReserve) external virtual override whenNotPaused(26) returns(uint256) {
        return abi.decode(callStrategy(externalRebalanceStrategy, abi.encodeCall(IVaultReserveStrategy._reserveLPTokens, (tokenId, lpTokens, isReserve))), (uint256));
    }

    /// @dev See {IVaultGammaPool-getReservedBalances}
    function getReservedBalances() external virtual override view returns(uint256, uint256) {
        return(s.getUint256(RESERVED_BORROWED_INVARIANT()), s.getUint256(RESERVED_LP_TOKENS()));
    }

    /// @dev See {IGammaPoolExternal-liquidateExternally}
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data)
        external override virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        return (0, new uint256[](0));
    }

    /// @dev See {IGammaPool-batchLiquidations}
    function batchLiquidations(uint256[] calldata tokenIds) external virtual override returns(uint256 totalLoanLiquidity, uint256[] memory refund) {
        return (0, new uint256[](0));
    }

    /// @dev See {GammaPoolERC4626-maxAssets}
    function maxAssets(uint256 assets) internal view virtual override returns(uint256) {
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE; // CFMM LP tokens in GammaPool that have not been borrowed
        lpTokenBalance = lpTokenBalance - GSMath.min(s.getUint256(RESERVED_LP_TOKENS()), lpTokenBalance);
        if(assets < lpTokenBalance){ // limit assets available to withdraw to what has not been borrowed
            return assets;
        }
        return lpTokenBalance;
    }

    /// @dev See {GammaPoolERC4626-_totalAssetsAndSupply}
    function _totalAssetsAndSupply() internal view virtual override returns (uint256 assets, uint256 supply) {
        address _factory = s.factory;
        (assets, supply) = IVaultShortStrategy(vaultImplementation()).totalReservedAssetsAndSupply(
            IVaultShortStrategy.VaultReservedBalancesParams({
                factory: _factory,
                pool: address(this),
                paramsStore: _factory,
                BORROWED_INVARIANT: s.BORROWED_INVARIANT,
                RESERVED_BORROWED_INVARIANT: s.getUint256(RESERVED_BORROWED_INVARIANT()),
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

    function RESERVED_LP_TOKENS() internal virtual pure returns(uint256) {
        return uint256(0x1d4997f9934f878df7106acada1ff771325c95fb5c98472c2bbed4497048bf65);
    }

    function RESERVED_BORROWED_INVARIANT() internal virtual pure returns(uint256) {
        return uint256(0x54f559f312bc80877ff037529d330829149d3630a04e9d467f30196e91b6ad9d);
    }
}
