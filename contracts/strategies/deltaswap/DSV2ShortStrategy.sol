// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../interfaces/external/deltaswap/IDSV2Pair.sol";
import "../cpmm/CPMMShortStrategy.sol";

/// @title External Long Strategy concrete implementation contract for Streaming Yield Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with DeltaSwapV2's streaming yield
contract DSV2ShortStrategy is CPMMShortStrategy {
    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_,
        uint64 slope2_) CPMMShortStrategy(maxTotalApy_, blocksPerYear_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {IShortStrategy-_getLatestCFMMInvariant}.
    function _getLatestCFMMInvariant(bytes memory _cfmm) public virtual override view returns(uint256 cfmmInvariant) {
        address cfmm_ = abi.decode(_cfmm, (address));
        uint128[] memory reserves = getLPReserves(cfmm_, true);
        cfmmInvariant = calcInvariant(address(0), reserves);
    }

    /// @dev See {BaseStrategy-getReserves}.
    function getLPReserves(address cfmm, bool isLatest) internal virtual override(BaseStrategy, CPMMBaseStrategy) view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = IDSV2Pair(cfmm).getLPReserves();
    }
}
