pragma solidity ^0.8.0;

interface IDSPair {

    /// @notice Read reserve token quantities in the AMM, and timestamp of last update
    /// @dev Reserve quantities come back as uint112 although we store them as uint128
    /// @return reserve0 - quantity of token0 held in AMM
    /// @return reserve1 - quantity of token1 held in AMM
    /// @return blockTimestampLast - timestamp of the last update block
    function getLPReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
