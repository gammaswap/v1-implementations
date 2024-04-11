pragma solidity ^0.8.0;

import "../../interfaces/external/deltaswap/IDSPair.sol";
import "../cpmm/CPMMShortStrategy.sol";

contract DSShortStrategy is CPMMShortStrategy {
    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_,
        uint64 slope2_) CPMMShortStrategy(maxTotalApy_, blocksPerYear_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {BaseStrategy-getReserves}.
    function getLPReserves(address cfmm, bool isLatest) internal virtual override(BaseStrategy, CPMMBaseStrategy) view returns(uint128[] memory reserves) {
        (reserves[0], reserves[1],) = IDSPair(cfmm).getLPReserves();
    }
}
