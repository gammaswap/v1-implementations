// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../strategies/base/LongStrategy.sol";
import "../../libraries/Math.sol";

contract TestLongStrategy is LongStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);

    constructor() {
        GammaPoolStorage.init();
    }

    function tokens() public virtual view returns(address[] memory) {
        return GammaPoolStorage.store().tokens;
    }

    function tokenBalances() public virtual view returns(uint256[] memory) {
        return GammaPoolStorage.store().TOKEN_BALANCE;
    }

    // **** LONG GAMMA **** //
    function createLoan() external virtual {
        uint256 tokenId = GammaPoolStorage.createLoan();
        emit LoanCreated(msg.sender, tokenId);
    }

    function getLoan(uint256 tokenId) public virtual view returns(uint256 id, address poolId, uint256[] memory tokensHeld,
        uint256 heldLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex, uint256 blockNum) {
        GammaPoolStorage.Loan storage _loan = getLoan(GammaPoolStorage.store(), tokenId);
        id = _loan.id;
        poolId = _loan.poolId;
        tokensHeld = _loan.tokensHeld;
        heldLiquidity = _loan.heldLiquidity;
        liquidity = _loan.liquidity;
        lpTokens = _loan.lpTokens;
        rateIndex = _loan.rateIndex;
        blockNum = _loan.blockNum;
    }

    function setLiquidity(uint256 tokenId, uint256 liquidity) public virtual {
        GammaPoolStorage.Loan storage _loan = getLoan(GammaPoolStorage.store(), tokenId);
        _loan.liquidity = liquidity;
    }

    function setHeldLiquidity(uint256 tokenId, uint256 heldLiquidity) public virtual {
        GammaPoolStorage.Loan storage _loan = getLoan(GammaPoolStorage.store(), tokenId);
        _loan.heldLiquidity = heldLiquidity;
    }

    function checkMargin(uint256 tokenId, uint24 limit) public virtual view returns(bool) {
        GammaPoolStorage.Loan storage _loan = getLoan(GammaPoolStorage.store(), tokenId);
        checkMargin(_loan, limit);
        return true;
    }

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
        return Math.sqrt(amounts[0] * amounts[1]);
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256 liquidity) {
        return 1;
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
    }
}
