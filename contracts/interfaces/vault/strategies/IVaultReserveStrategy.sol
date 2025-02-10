// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface Vault Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Used to reserve LP tokens for vault to use in a future call to borrowLiquidity().
interface IVaultReserveStrategy {
    /// @dev reserve LP tokens for future borrowing (prevents others from borrowing) or free reserved LP tokens so others can borrow them.
    /// @param tokenId - tokenId of loan used to reserve or free reserved LP tokens. Must be refType 3.
    /// @param lpTokens - number of LP tokens that must be reserved or freed.
    /// @param isReserve - if true then reserve LP tokens, if false, then free reserved LP tokens.
    /// @return reservedLPTokens - LP tokens that have been reserved or freed.
    function _reserveLPTokens(uint256 tokenId, uint256 lpTokens, bool isReserve) external returns(uint256);
}
