// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../interfaces/external/deltaswap/IDSV2Pair.sol";
import "../../cpmm/liquidation/CPMMLiquidationStrategy.sol";

/// @title Liquidation Strategy concrete implementation contract for Streaming Yield Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by LiquidationStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with DeltaSwapV2's streaming yield
contract DSV2LiquidationStrategy is CPMMLiquidationStrategy {
    /// @dev Initializes the contract by setting `liquidator`, `mathLib`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `tradingFee1`, `tradingFee2`, `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address liquidator_, address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_,
        uint24 tradingFee2_, address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_)
        CPMMLiquidationStrategy(liquidator_, mathLib_, maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_,
        baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseStrategy-getReserves}.
    function getLPReserves(address cfmm, bool isLatest) internal virtual override(BaseStrategy, CPMMBaseStrategy) view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = IDSV2Pair(cfmm).getLPReserves();
    }

    /// @dev See {CPMMBaseLongStrategy-getTradingFee1}.
    function getTradingFee1() internal virtual override view returns(uint24) {
        (,,,uint16 gsFee,,,) = IDSV2Pair(s.cfmm).getFeeParameters();
        return tradingFee2 - gsFee;
    }
}