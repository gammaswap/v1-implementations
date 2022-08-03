pragma solidity ^0.8.0;

abstract contract AbstractRateModel {
    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual view returns(uint256);
}
