// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@gammaswap/v1-core/contracts/strategies/LiquidationStrategy.sol";
import "./CPMMLongStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMLiquidationStrategy is CPMMBaseLongStrategy, LiquidationStrategy {

    /// @return LIQUIDATION_FEE_THRESHOLD - 1 - feeThreshold % = liquidation penalty charged at collateral
    uint16 immutable public LIQUIDATION_FEE_THRESHOLD;

    /// @dev Initializes the contract by setting `_liquidationThreshold`, `_liquidationFeeThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
    constructor(uint16 _liquidationThreshold, uint16 _liquidationFeeThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseLongStrategy(_liquidationThreshold, _maxTotalApy, _blocksPerYear, 0, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
        LIQUIDATION_FEE_THRESHOLD = _liquidationFeeThreshold;
    }

    /// @dev returns liquidation fee threshold
    function liquidationFeeThreshold() internal virtual override view returns(uint16) {
        return LIQUIDATION_FEE_THRESHOLD;
    }
}
