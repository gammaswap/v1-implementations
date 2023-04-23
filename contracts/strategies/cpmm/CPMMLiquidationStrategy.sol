// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/LiquidationStrategy.sol";
import "./CPMMLongStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMLiquidationStrategy is CPMMBaseLongStrategy, LiquidationStrategy {

    /// @return LIQUIDATION_FEE - liquidation penalty charged from collateral
    uint16 immutable public LIQUIDATION_FEE;

    /// @dev Initializes the contract by setting `_liquidationThreshold`, `_liquidationFee`, `_maxTotalApy`, `_blocksPerYear`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
    constructor(uint16 _liquidationThreshold, uint16 _liquidationFee, uint256 _maxTotalApy, uint256 _blocksPerYear, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseLongStrategy(_liquidationThreshold, _maxTotalApy, _blocksPerYear, 0, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
        LIQUIDATION_FEE = _liquidationFee;
    }

    /// @dev returns liquidation fee threshold
    function _liquidationFee() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE;
    }
}
