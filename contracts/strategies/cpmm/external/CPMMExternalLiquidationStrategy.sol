// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/external/ExternalLiquidationStrategy.sol";
import "../CPMMLiquidationStrategy.sol";

/// @title External Liquidation Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice LiquidationStrategy implementation for Constant Product Market Maker that also allows external swaps (flash loans) during liquidations
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMExternalLiquidationStrategy is CPMMLiquidationStrategy, ExternalLiquidationStrategy {

    /// @return EXTERNAL_SWAP_FEE - fees charged to flash loans
    uint256 public immutable EXTERNAL_SWAP_FEE;

    /// @dev Initializes the contract by setting `_extSwapFee`, `_liquidationThreshold`, `_liquidationFeeThreshold`, `_maxTotalApy`, `_blocksPerYear`, `_tradingFee1`, `_tradingFee2`, `_baseRate`, `_factor`, and `_maxApy`
    constructor(uint256 _extSwapFee, uint16 _liquidationThreshold, uint16 _liquidationFeeThreshold, uint256 _maxTotalApy, uint256 _blocksPerYear, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMLiquidationStrategy(_liquidationThreshold, _liquidationFeeThreshold, _maxTotalApy, _blocksPerYear, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
        EXTERNAL_SWAP_FEE = _extSwapFee;
    }

    /// @dev See {ExternalBaseStrategy-externalSwapFee}
    function externalSwapFee() internal view virtual override returns(uint256) {
        return EXTERNAL_SWAP_FEE;
    }
}
