// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../interfaces/external/deltaswap/IDSPair.sol";
import "../../cpmm/rebalance/CPMMExternalRebalanceStrategy.sol";

/// @title External Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with UniswapV2
contract DSExternalRebalanceStrategy is CPMMExternalRebalanceStrategy {

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_, address feeSource_,
        uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMExternalRebalanceStrategy(maxTotalApy_,
        blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseStrategy-getReserves}.
    function getLPReserves(address cfmm, bool isLatest) internal virtual override(BaseStrategy, CPMMBaseStrategy) view returns(uint128[] memory reserves) {
        (reserves[0], reserves[1],) = IDSPair(cfmm).getLPReserves();
    }
}