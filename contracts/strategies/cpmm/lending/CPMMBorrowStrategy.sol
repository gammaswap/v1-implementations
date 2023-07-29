// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/lending/BorrowStrategy.sol";
import "@gammaswap/v1-core/contracts/strategies/rebalance/RebalanceStrategy.sol";
import "../base/CPMMBaseRebalanceStrategy.sol";

/// @title Borrow and Rebalance Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BorrowStrategy and RebalanceStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMBorrowStrategy is CPMMBaseRebalanceStrategy, BorrowStrategy, RebalanceStrategy {

    /// @dev Initializes the contract by setting `mathLib`, `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_,
        uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_, uint80 maxApy_)
        CPMMBaseRebalanceStrategy(mathLib_, ltvThreshold_, maxTotalApy_, blocksPerYear_,
        tradingFee1_, tradingFee2_, baseRate_, factor_, maxApy_) {
    }

    /// @dev See {BaseBorrowStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }
}
