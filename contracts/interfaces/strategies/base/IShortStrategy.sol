// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IShortStrategy {
    function mint(address to) external returns(uint256 shares);
    function withdrawReserves(address to) external returns(uint256[] memory reserves, uint256 assets);
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    function getBorrowRate(uint256 lpBalance, uint256 lpBorrowed) external view returns(uint256);
    function calcFeeIndex(address cfmm, uint256 borrowRate, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum)
        external view returns(uint256 lastFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply);
    function calcBorrowedLPTokensPlusInterest(uint256 borrowedInvariant, uint256 lastFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) external pure returns(uint256);
    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum) external view returns(uint256);

    /***** ERC4626 Functions *****/

    function _deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function _mint(uint256 shares, address receiver) external returns (uint256 assets);
    function _withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function _redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
}