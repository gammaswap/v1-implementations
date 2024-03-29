// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for CPMM Math library
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Interface to call math functions to perform calculations used in CPMM strategies
interface ICPMMMath {

    /// @param delta - quantity of token0 bought from CFMM to achieve max collateral
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param fee1 - trading fee numerator
    /// @param fee2 - trading fee denominator
    /// @return collateral - max collateral liquidity value of tokensHeld after trade using deltas given reserves in CFMM
    function calcCollateralPostTrade(uint256 delta, uint256 tokensHeld0, uint256 tokensHeld1, uint256 reserve0,
        uint256 reserve1, uint256 fee1, uint256 fee2) external view returns(uint256 collateral);

    /// @dev Calculate quantities to trade to rebalance collateral (`tokensHeld`) to the desired `ratio`
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param fee1 - trading fee numerator
    /// @param fee2 - trading fee denominator
    /// @param decimals0 - decimals of token0
    /// @return deltas - quadratic roots (quantities to trade). The first quadratic root (index 0) is the only feasible trade
    function calcDeltasForMaxLP(uint256 tokensHeld0, uint256 tokensHeld1, uint256 reserve0, uint256 reserve1,
        uint256 fee1, uint256 fee2, uint8 decimals0) external view returns(int256[] memory deltas);

    /// @dev Calculate quantities to trade to rebalance collateral (`tokensHeld`) to the desired `ratio`
    /// @param liquidity - liquidity debt that needs to be repaid after rebalancing loan's collateral quantities
    /// @param ratio0 - numerator (token0) of desired ratio we wish collateral (`tokensHeld`) to have
    /// @param ratio1 - denominator (token1) of desired ratio we wish collateral (`tokensHeld`) to have
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param decimals0 - decimals of token0
    /// @return deltas - quadratic roots (quantities to trade). The first quadratic root (index 0) is the only feasible trade
    function calcDeltasToCloseSetRatio(uint256 liquidity, uint256 ratio0, uint256 ratio1, uint256 tokensHeld0, uint256 tokensHeld1,
        uint256 reserve0, uint256 reserve1, uint8 decimals0) external view returns(int256[] memory deltas);

    /// @dev how much collateral to trade to have enough to close a position
    /// @param liquidity - liquidity debt that needs to be repaid after rebalancing loan's collateral quantities
    /// @param lastCFMMInvariant - most up to date invariant in CFMM
    /// @param collateral - collateral invariant of loan to rebalance (not token quantities, but their geometric mean)
    /// @param reserve - reserve quantity of token to trade in CFMM
    /// @return delta - quantity of token to trade (> 0 means buy, < 0 means sell)
    function calcDeltasToClose(uint256 liquidity, uint256 lastCFMMInvariant, uint256 collateral, uint256 reserve)
        external pure returns(int256 delta);

    /// @dev Calculate quantities to trade to rebalance collateral (`tokensHeld`) to the desired `ratio`
    /// @param ratio0 - numerator (token0) of desired ratio we wish collateral (`tokensHeld`) to have
    /// @param ratio1 - denominator (token1) of desired ratio we wish collateral (`tokensHeld`) to have
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantity of token0 in CFMM
    /// @param reserve1 - reserve quantity of token1 in CFMM
    /// @param fee1 - trading fee numerator
    /// @param fee2 - trading fee denominator
    /// @return deltas - quadratic roots (quantities to trade). The first quadratic root (index 0) is the only feasible trade
    function calcDeltasForRatio(uint256 ratio0, uint256 ratio1, uint256 tokensHeld0, uint256 tokensHeld1,
        uint256 reserve0, uint256 reserve1, uint256 fee1, uint256 fee2) external view returns(int256[] memory deltas);

    /// @dev Calculate deltas to rebalance collateral for withdrawal while maintaining desired ratio
    /// @param amount - amount of token0 requesting to withdraw
    /// @param ratio0 - numerator of desired ratio to maintain after withdrawal (token0)
    /// @param ratio1 - denominator of desired ratio to maintain after withdrawal (token1)
    /// @param tokensHeld0 - quantities of token0 available in loan as collateral
    /// @param tokensHeld1 - quantities of token1 available in loan as collateral
    /// @param reserve0 - reserve quantities of token0 in CFMM
    /// @param reserve1 - reserve quantities of token1 in CFMM
    /// @param fee1 - trading fee numerator
    /// @param fee2 - trading fee denominator
    /// @return deltas - quantities of reserve tokens to rebalance after withdrawal. The second quadratic root (index 1) is the only feasible trade
    function calcDeltasForWithdrawal(uint256 amount, uint256 ratio0, uint256 ratio1, uint256 tokensHeld0, uint256 tokensHeld1,
        uint256 reserve0, uint256 reserve1, uint256 fee1, uint256 fee2) external view returns(int256[] memory deltas);
}
