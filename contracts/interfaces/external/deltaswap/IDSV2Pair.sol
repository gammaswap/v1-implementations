// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../cpmm/ICPMM.sol";

/// @title Interface for DeltaSwapV2 CFMM implementations
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Interface to get reserve tokens, deposit liquidity, withdraw liquidity, and swap tokens
/// @dev Interface assumes an UniswapV2 interface. Function mint() is used to deposit and burn() to withdraw
interface IDSV2Pair is ICPMM {

    /// @notice Read reserve token quantities in the AMM, and timestamp of last update
    /// @dev Reserve quantities come back as uint112 although we store them as uint128
    /// @return reserve0 - quantity of token0 held in AMM
    /// @return reserve1 - quantity of token1 held in AMM
    /// @return rate - rate of growth of LP liquidity over the yield period
    function getLPReserves() external view returns (uint112 reserve0, uint112 reserve1, uint256 rate);

    /// @dev Get parameters used in fee calculation
    /// @return _gammaPool - gammapool DeltaSwap pool is for
    /// @return _stream0 - stream donations of token0 over the yield period
    /// @return _stream1 - stream donations of token1 over the yield period
    /// @return _gsFee - swap fee for gammaswap only
    /// @return _dsFee - swap fee
    /// @return _dsFeeThreshold - trehshold at which fees apply to swaps
    /// @return _yieldPeriod - yield period in seconds
    function getFeeParameters() external view returns(address _gammaPool, bool _stream0, bool _stream1, uint16 _gsFee, uint16 _dsFee, uint24 _dsFeeThreshold, uint24 _yieldPeriod);

    /// @dev Geometric mean of LP reserves
    function rootK0() external view returns(uint112);
}
