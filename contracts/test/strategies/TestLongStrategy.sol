// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../strategies/base/LongStrategy.sol";

contract TestLongStrategy is LongStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);

    constructor() {
        GammaPoolStorage.init();
    }

    // **** LONG GAMMA **** //
    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = GammaPoolStorage.createLoan();
        emit LoanCreated(msg.sender, tokenId);
    }

    /*function calcRepayAmounts() public virtual {
        calcRepayAmounts(GammaPoolStorage.store());
    }/**/

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        return 1;
    }

    //LongGamma
    function calcRepayAmounts(GammaPoolStorage.Store storage store, uint256 liquidity, uint256[] storage tokensHeld)
        internal override virtual returns(uint256[] memory _tokensHeld, uint256[] memory amounts) {
        _tokensHeld = new uint256[](2);
        amounts = new uint256[](2);
    }

    function rebalancePosition(GammaPoolStorage.Store storage store, int256[] calldata deltas, uint256[] storage tokensHeld) internal virtual
        override returns(uint256[] memory _tokensHeld) {
        _tokensHeld = new uint256[](2);
    }

    function updateReserves(GammaPoolStorage.Store storage store) internal override virtual {

    }

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual override view returns(uint256) {
        return 1;
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256 liquidity) {
        return 1;
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
    }
}
