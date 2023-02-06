// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Interface for UniswapV2Pair contract and its clones
/// @author Daniel D. Alcarraz
/// @notice Interface to get reserve tokens, deposit liquidity, withdraw liquidity, and swap tokens
/// @dev Interface assumes an UniswapV2 implementation. Function mint() is used to deposit and burn() to withdraw
interface ICPMM {
    /// @notice Read reserve token quantities in the AMM, and timestamp of last update
    /// @dev Reserve quantities come back as uint112 although we store them as uint128
    /// @return reserve0 - quantity of token0 held in AMM
    /// @return reserve1 - quantity of token1 held in AMM
    /// @return blockTimestampLast - timestamp of the last update block
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    /// @notice Deposit reserve tokens (liquidity) to get LP tokens, requires having sent reserve tokens before calling function
    /// @dev requires sending the reserve tokens in the correct ratio. An incorrect ratio will cause some loss of funds
    /// @param to - address that will receive LP tokens
    /// @return liquidity - LP tokens representing liquidity deposited
    function mint(address to) external returns (uint liquidity);

    /// @notice Withdraw reserve tokens (liquidity) by burning LP tokens, requires having sent LP tokens before calling function
    /// @dev Amounts of reserve tokens you receive match the ratio of reserve tokens in the AMM at the time you call this function
    /// @param to - address that will receive reserve tokens
    /// @return amount0 - quantity withdrawn of token0 LP token represents
    /// @return amount1 - quantity withdrawn of token1 LP token represents
    function burn(address to) external returns (uint amount0, uint amount1);

    /// @notice Exchange one token for another token, must send token amount to exchange first before calling this function
    /// @dev The user specifies which token amount to get. Therefore only one token amount parameter is greater than zero
    /// @param amount0Out - address that will receive reserve tokens
    /// @param amount1Out - address that will receive reserve tokens
    /// @param to - address that will receive output token quantity
    /// @param data - used for flash loan trades
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}
