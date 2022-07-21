// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IGammaPoolFactory.sol";
import "./libraries/GammaPoolStorage.sol";

contract GammaPool2 {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    constructor() {
        GammaPoolStorage.init();
    }

    function createLoan() external virtual lock returns(uint tokenId) {
        tokenId = GammaPoolStorage.createLoan();
    }

    function loans(uint256 tokenId) external virtual view returns (uint256 id, address poolId,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum) {
        GammaPoolStorage.Loan memory loan = GammaPoolStorage.store().loans[tokenId];
        return (loan.id, loan.poolId, loan.tokensHeld, loan.liquidity, loan.rateIndex, loan.blockNum);
    }
}
