// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./VaultGammaPool.sol";

/// @title Vault GammaPool implementation for Constant Product Market Maker in mainnet Ethereum
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev This implementation is specifically for validating UniswapV2Pair and clone contracts
/// @dev Overrides the initialize function to set params for higher network costs in mainnet Ethereum
contract VaultGammaPoolMain is VaultGammaPool {

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `borrowStrategy`, `repayStrategy`, `rebalanceStrategy`,
    /// @dev `shortStrategy`, `liquidationStrategy`, `batchLiquidationStrategy`, `cfmmFactory`, and `cfmmInitCodeHash`.
    constructor(InitializationParams memory params) VaultGammaPool(params) {
    }

    /// @dev See {IGammaPool-initialize}
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals, uint72 _minBorrow, bytes calldata) external virtual override {
        if(msg.sender != factory) revert Forbidden(); // only factory is allowed to initialize
        s.initialize(factory, _cfmm, protocolId, _tokens, _decimals, _minBorrow);
        s.ltvThreshold = 15; // 150 basis points
        s.liquidationFee = 125; // 125 basis points
    }
}
