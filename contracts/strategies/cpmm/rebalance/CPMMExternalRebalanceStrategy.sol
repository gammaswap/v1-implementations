// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/rebalance/ExternalRebalanceStrategy.sol";
import "../base/CPMMBaseLongStrategy.sol";

/// @title External Long Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMExternalRebalanceStrategy is CPMMBaseLongStrategy, ExternalRebalanceStrategy {

    /// @return EXTERNAL_SWAP_FEE - fees charged to flash loans
    uint256 immutable public EXTERNAL_SWAP_FEE;

    /// @dev Initializes the contract by setting `EXTERNAL_SWAP_FEE`, `LTV_THRESHOLD`, `MAX_TOTAL_APY`,
    /// @dev `BLOCKS_PER_YEAR`, `origFee`, `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(uint256 extSwapFee_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_,
        uint16 origFee_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_, uint80 maxApy_)
        CPMMBaseLongStrategy(ltvThreshold_, maxTotalApy_, blocksPerYear_, origFee_, tradingFee1_,
        tradingFee2_, baseRate_, factor_, maxApy_) {

        EXTERNAL_SWAP_FEE = extSwapFee_;
    }

    /// @dev See {ExternalBaseStrategy-externalSwapFee}
    function externalSwapFee() internal view virtual override returns(uint256) {
        return EXTERNAL_SWAP_FEE;
    }
}
