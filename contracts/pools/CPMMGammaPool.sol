// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/base/GammaPool.sol";
import "@gammaswap/v1-core/contracts/base/GammaPoolExternal.sol";
import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "@gammaswap/v1-core/contracts/libraries/GammaSwapLibrary.sol";
import "@gammaswap/v1-core/contracts/libraries/GSMath.sol";
import "../interfaces/cpmm/strategies/ICPMMRebalanceStrategy.sol";
import "../interfaces/cpmm/ICPMMGammaPool.sol";

/// @title GammaPool implementation for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev This implementation is specifically for validating UniswapV2Pair and clone contracts
contract CPMMGammaPool is GammaPool, GammaPoolExternal, ICPMMGammaPool {

    error NotContract();
    error BadProtocol();
    error InvalidTokensLength();

    using LibStorage for LibStorage.Storage;

    /// @return cfmmFactory - factory contract that created CFMM
    address immutable public cfmmFactory;

    /// @return cfmmInitCodeHash - init code hash of CFMM
    bytes32 immutable public cfmmInitCodeHash;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `borrowStrategy`, `repayStrategy`, `rebalanceStrategy`,
    /// @dev `shortStrategy`, `liquidationStrategy`, `batchLiquidationStrategy`, `cfmmFactory`, and `cfmmInitCodeHash`.
    constructor(InitializationParams memory params) GammaPool(params.protocolId, params.factory, params.borrowStrategy,
        params.repayStrategy, params.rebalanceStrategy, params.shortStrategy, params.liquidationStrategy,
        params.batchLiquidationStrategy, params.viewer) GammaPoolExternal(params.externalRebalanceStrategy,
        params.externalLiquidationStrategy) {
        cfmmFactory = params.cfmmFactory;
        cfmmInitCodeHash = params.cfmmInitCodeHash;
    }

    /// @dev See {IGammaPool-createLoan}
    function createLoan(uint16 refId) external lock virtual override whenNotPaused(9) returns(uint256 tokenId) {
        tokenId = s.createLoan(2, refId); // only 2 token pair
        emit LoanCreated(msg.sender, tokenId, refId);
    }

    /// @dev See {GammaPoolERC4626._calcInvariant}.
    function _calcInvariant(uint128[] memory tokensHeld) internal virtual override view returns(uint256) {
        return GSMath.sqrt(uint256(tokensHeld[0]) * tokensHeld[1]);
    }

    /// @dev See {GammaPoolERC4626._getLastCFMMPrice}.
    function _getLastCFMMPrice() internal virtual override view returns(uint256) {
        uint128[] memory _reserves = _getLatestCFMMReserves();
        if(_reserves[0] == 0) {
            return 0;
        }
        return _reserves[1] * (10 ** s.decimals[0]) / _reserves[0];
    }

    /// @dev See {IGammaPool-validateCFMM}
    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata) external virtual override view
        returns(address[] memory _tokensOrdered) {
        if(!GammaSwapLibrary.isContract(_cfmm)) revert NotContract(); // Not a smart contract (hence not a CFMM) or not instantiated yet
        if(_tokens.length != 2) revert InvalidTokensLength();

        // Order tokens to match order of tokens in CFMM
        _tokensOrdered = new address[](2);
        (_tokensOrdered[0], _tokensOrdered[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);

        // Verify CFMM was created by CFMM's factory contract
        if(_cfmm != AddressCalculator.calcAddress(cfmmFactory,
            keccak256(abi.encodePacked(_tokensOrdered[0], _tokensOrdered[1])),cfmmInitCodeHash)) {
            revert BadProtocol();
        }
    }

    /// @dev See {ICPMMGammaPool-setMaxTotalAPY}
    function setMaxTotalAPY(uint256 _maxTotalAPY) external virtual override {
        abi.decode(callStrategy(rebalanceStrategy, abi.encodeCall(ICPMMRebalanceStrategy._setMaxTotalAPY, _maxTotalAPY)), ());
    }

    /// @dev See {IGammaPoolExternal-liquidateExternally}
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data)
        external override virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        return (0, new uint256[](0));
    }
}
