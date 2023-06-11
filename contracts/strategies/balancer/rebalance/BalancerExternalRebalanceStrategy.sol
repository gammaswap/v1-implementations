// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/rebalance/ExternalRebalanceStrategy.sol";
import "../base/BalancerBaseLongStrategy.sol";

/// @title External Long Strategy concrete implementation contract for Balancer AMM
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Constant Product Market Maker Long Strategy implementation that allows external swaps (flash loans)
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerExternalRebalanceStrategy is BalancerBaseLongStrategy, ExternalRebalanceStrategy {

    /// @return EXTERNAL_SWAP_FEE - fees charged to flash loans
    uint256 immutable public EXTERNAL_SWAP_FEE;

    /// @dev Initializes the contract by setting `EXTERNAL_SWAP_FEE`, `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `origFee`, `baseRate`, `factor`, `maxApy`, and `weight0`
    constructor(uint256 extSwapFee_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint16 origFee_,
        uint64 baseRate_, uint80 factor_, uint80 maxApy_, uint256 weight0_) BalancerBaseLongStrategy(ltvThreshold_,
        maxTotalApy_, blocksPerYear_, origFee_, baseRate_, factor_, maxApy_, weight0_) {

        EXTERNAL_SWAP_FEE = extSwapFee_;
    }

    /// @dev See {ExternalBaseStrategy-externalSwapFee}
    function externalSwapFee() internal view virtual override returns(uint256) {
        return EXTERNAL_SWAP_FEE;
    }
}
