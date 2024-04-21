// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for contract that has fee information for transacting with AMM
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Used primarily with DeltaSwap
interface IFeeSource {
    /// @dev Get fee charged to GammaSwap from feeSource contract in basis points (e.g. 3 = 3 basis points)
    function gsFee() external view returns(uint8);
}
