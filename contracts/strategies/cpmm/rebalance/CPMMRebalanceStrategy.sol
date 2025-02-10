// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/rebalance/RebalanceStrategy.sol";
import "../../../interfaces/cpmm/strategies/ICPMMRebalanceStrategy.sol";
import "../base/CPMMBaseRebalanceStrategy.sol";

/// @title Rebalance Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by BorrowStrategy and RebalanceStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMRebalanceStrategy is CPMMBaseRebalanceStrategy, RebalanceStrategy, ICPMMRebalanceStrategy {

    using LibStorage for LibStorage.Storage;

    /// @dev Initializes the contract by setting `mathLib`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_,
        address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseRebalanceStrategy(mathLib_,
        maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    /// @dev See {ICPMMRebalanceStrategy-_setMaxTotalAPY}.
    function _setMaxTotalAPY(uint256 _maxTotalAPY) external virtual override {
        if(msg.sender != s.factory) revert Forbidden(); // only factory is allowed to set Max Total APY
        if(_maxTotalAPY > 0 && _maxTotalAPY < baseRate + slope1 + slope2) revert MaxTotalApy();

        s.setUint256(uint256(MAX_TOTAL_APY_KEY), _maxTotalAPY);

        emit SetMaxTotalAPY(_maxTotalAPY);
    }
}
