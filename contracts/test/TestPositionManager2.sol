// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@gammaswap/v1-periphery/contracts/PositionManager.sol";

contract TestPositionManager2 is PositionManager {

    event Deposit(address indexed caller, address indexed to, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed to, address indexed from, uint256 assets, uint256 shares);

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
    uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);
    event LoanCreated(address indexed caller, uint256 tokenId);
    event LoanUpdated(uint256 indexed tokenId, uint256[] tokensHeld, uint256 heldLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    constructor(address _factory, address _WETH) PositionManager(_factory, _WETH) {}
}
