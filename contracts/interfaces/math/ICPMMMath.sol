// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for CPMM Math library
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Interface to call math functions to perform calculations used in CPMM strategies
interface ICPMMMath {

    /// @dev how much collateral to trade to have enough to close a position
    /// @param lastCFMMInvariant - most up to date invariant in CFMM
    /// @param reserve - reserve quantity of token to trade in CFMM
    /// @param collateral - collateral invariant of loan to rebalance (not token quantities, but their geometric mean)
    /// @param liquidity - liquidity debt that needs to be repaid after rebalancing loan's collateral quantities
    /// @return delta - quantity of token to trade (> 0 means buy, < 0 means sell)
    function calcDeltasToClose(uint256 lastCFMMInvariant, uint256 reserve, uint256 collateral, uint256 liquidity)
        external pure returns(int256 delta);

    /// @dev Calculate quantities to trade to rebalance collateral (`tokensHeld`) to the desired `ratio`
    /// @param ratio - desired ratio we wish collateral (`tokensHeld`) to have
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param tokensHeld - collateral to rebalance
    /// @param factor - decimals expansion number of first token (e.g. 10^(token0's decimals))
    /// @param side - side of token to rebalance
    /// @param fee1 - trading fee numerator
    /// @param fee2 - trading fee denominator
    /// @return deltas - quadratic roots (quantities to trade). The first quadratic root (index 0) is the only feasible trade
    function calcDeltasForRatio(uint256 ratio, uint128 reserve0, uint128 reserve1, uint128[] memory tokensHeld,
        uint256 factor, bool side, uint256 fee1, uint256 fee2) external pure returns(int256[] memory deltas);

    /// @dev Calculate deltas to rebalance collateral for withdrawal while maintaining desired ratio
    /// @param amount - amount of token0 requesting to withdraw
    /// @param tokensHeld0 - quantities of collateral available in loan
    /// @param tokensHeld1 - quantities of collateral available in loan
    /// @param reserve0 - reserve quantities of collateral of token0 in CFMM
    /// @param reserve1 - reserve quantities of collateral of token1 in CFMM
    /// @param ratio0 - desired ratio to maintain after withdrawal
    /// @param ratio1 - desired ratio to maintain after withdrawal
    /// @param fee1 - trading fee numerator
    /// @param fee2 - trading fee denominator
    /// @return deltas - quantities of reserve tokens to rebalance after withdrawal
    function calcDeltasForWithdrawal(uint128 amount, uint128 tokensHeld0, uint128 tokensHeld1, uint128 reserve0, uint128 reserve1,
        uint256 ratio0, uint256 ratio1, uint256 fee1, uint256 fee2) external pure returns(int256[] memory deltas);
}
