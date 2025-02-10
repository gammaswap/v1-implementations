// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./VaultGammaPool.sol";

/// @title Vault GammaPool implementation for Constant Product Market Maker in mainnet Ethereum
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev This implementation is specifically for validating UniswapV2Pair and clone contracts
/// @dev Overrides the initialize function to set params for higher network costs in mainnet Ethereum
contract VaultGammaPoolMain is VaultGammaPool {

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `borrowStrategy`, `repayStrategy`,
    /// @dev `shortStrategy`, `liquidationStrategy`, `batchLiquidationStrategy`, `cfmmFactory`, and `cfmmInitCodeHash`.
    constructor(uint16 _protocolId, address _factory, address _borrowStrategy, address _repayStrategy,
        address _shortStrategy, address _liquidationStrategy, address _batchLiquidationStrategy, address _viewer,
        address _externalRebalanceStrategy, address _externalLiquidationStrategy, address _cfmmFactory,
        bytes32 _cfmmInitCodeHash) VaultGammaPool(_protocolId, _factory, _borrowStrategy, _repayStrategy,
        _shortStrategy, _liquidationStrategy, _batchLiquidationStrategy, _viewer, _externalRebalanceStrategy,
        _externalLiquidationStrategy, _cfmmFactory, _cfmmInitCodeHash) {
    }

    /// @dev See {IGammaPool-initialize}
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals, uint72 _minBorrow, bytes calldata) external virtual override {
        if(msg.sender != factory) revert Forbidden(); // only factory is allowed to initialize
        s.initialize(factory, _cfmm, protocolId, _tokens, _decimals, _minBorrow);
        s.ltvThreshold = 15; // 150 basis points
        s.liquidationFee = 125; // 125 basis points
    }
}
