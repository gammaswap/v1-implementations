// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

abstract contract AbstractRateModel {
    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual view returns(uint256);
}
