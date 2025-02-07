// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../interfaces/vault/strategies/IVaultStrategy.sol";
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
        return abi.decode(callStrategy(externalRebalanceStrategy, abi.encodeCall(IVaultStrategy._reserveLPTokens, (tokenId, lpTokens, isReserve))), (uint256));
    }

    /// @dev See {IVaultGammaPool-getReservedBalances}
    function getReservedBalances() external virtual override view returns(uint256 reservedBorrowedInvariant, uint256 reservedLPTokens) {
        reservedBorrowedInvariant = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_BORROWED_INVARIANT));
        reservedLPTokens = s.getUint256(uint256(IVaultGammaPool.StorageIndexes.RESERVED_LP_TOKENS));
    }

    /// @dev See {IGammaPool-repayLiquidityWithLP}
    function repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external virtual override whenNotPaused(15) returns(uint256 liquidityPaid, uint128[] memory tokensHeld) {
        return (0, new uint128[](0));
    }
}
