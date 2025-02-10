// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for Vault GammaPool smart contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used as template for building other Vault GammaPool contract implementations
interface IVaultGammaPool {

    /// @dev enum indices for storage fields saved for Vault GammaPool
    enum StorageIndexes { RESERVED_BORROWED_INVARIANT, RESERVED_LP_TOKENS }

    /// @dev reserve LP tokens for future borrowing (prevents others from borrowing) or free reserved LP tokens so others can borrow them.
    /// @param tokenId - tokenId of loan used to reserve or free reserved LP tokens. Must be refType 3.
    /// @param lpTokens - number of LP tokens that must be reserved or freed.
    /// @param isReserve - if true then reserve LP tokens, if false, then free reserved LP tokens.
    /// @return reservedLPTokens - LP tokens that have been reserved or freed.
    function reserveLPTokens(uint256 tokenId, uint256 lpTokens, bool isReserve) external returns(uint256);

    /// @dev Get borrowed invariant and LP tokens that have been reserved through refType 3 loans
    /// @return reservedBorrowedInvariant - borrowed invariant that is reserved for refType 3 loans
    /// @return reservedLPTokens - LP tokens reserved for future use by refType 3 loans
    function getReservedBalances() external view returns(uint256 reservedBorrowedInvariant, uint256 reservedLPTokens);
}
