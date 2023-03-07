// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/external/ExternalLongStrategy.sol";
import "../BalancerLongStrategy.sol";

/// @title External Long Strategy concrete implementation contract for Balancer AMM
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerExternalLongStrategy is BalancerLongStrategy, ExternalLongStrategy {

    /// @return EXTERNAL_SWAP_FEE - fees charged to flash loans
    uint256 public immutable EXTERNAL_SWAP_FEE;

    /// @dev Initializes the contract by setting `_extSwapFee`, `_ltvThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_originationFee`, `_baseRate`, `_factor`, `_maxApy`, and `_weight0`
    constructor(uint256 _extSwapFee, uint16 _ltvThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint16 _originationFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0)
        BalancerLongStrategy(_ltvThreshold, _maxTotalApy, _blocksPerYear, _originationFee, _baseRate, _factor, _maxApy, _weight0) {
        EXTERNAL_SWAP_FEE = _extSwapFee;
    }

    /// @dev See {ExternalBaseStrategy-externalSwapFee}
    function externalSwapFee() internal view virtual override returns(uint256) {
        return EXTERNAL_SWAP_FEE;
    }
}
