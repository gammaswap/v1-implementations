// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/LongStrategy.sol";
import "./CPMMBaseLongStrategy.sol";

/// @title Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LongStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMLongStrategy is CPMMBaseLongStrategy, LongStrategy {

    /// @dev Initializes the contract by setting `_ltvThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_originationFee`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
    constructor(uint16 _ltvThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint24 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseLongStrategy(_ltvThreshold, _maxTotalApy, _blocksPerYear, _originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    /// @dev See {BaseLongStrategy.getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }
}
