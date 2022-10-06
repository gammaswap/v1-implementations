// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../strategies/base/LongStrategy.sol";
import "../../libraries/Math.sol";

contract TestLongStrategy is LongStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);
    uint256 public borrowRate = 1;

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

    function setBorrowRate(uint256 _borrowRate) public virtual {
        borrowRate = _borrowRate;
    }

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        return borrowRate;
    }

    //LongGamma

    function calcRepayAmounts(GammaPoolStorage.Store storage store, uint256 liquidity)
        internal override virtual view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
    }

    function sendAmounts(GammaPoolStorage.Store storage store, address to, uint256[] memory amounts, bool force) internal virtual override {
        sendToken(store.tokens[0], to, amounts[0]);
        sendToken(store.tokens[1], to, amounts[1]);
    }

    function sendToken(address token, address to, uint256 amount) internal virtual {
        if(amount > 0) GammaSwapLibrary.safeTransfer(token, to, amount);
    }

    function calcDeltaAmounts(GammaPoolStorage.Store storage store, int256[] calldata deltas) internal virtual override view returns(uint256[] memory outAmts, uint256[] memory inAmts) {

    }

    function swapAmounts(GammaPoolStorage.Store storage store, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {

    }

    //BaseStrategy
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

    function testOpenLoan(uint256 tokenId, uint256 lpTokens) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);
        openLoan(_store, _loan, lpTokens);
    }

    /*function testPayLoan(uint256 tokenId, uint256 liquidity, uint256 lpTokens) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);
        payLoan(_store, _loan, liquidity, lpTokens);
    }/**/

    function setLPTokenBalance(uint256 lpTokenBalance, uint256 lpInvariant) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        _store.LP_TOKEN_BALANCE = lpTokenBalance;
        _store.LP_TOKEN_TOTAL = lpTokenBalance;
        _store.LP_INVARIANT = lpInvariant;
        _store.TOTAL_INVARIANT = lpInvariant;
    }

    function chargeLPTokenInterest(uint256 tokenId, uint256 lpTokenInterest) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);

        uint256 invariantInterest = lpTokenInterest * _store.LP_INVARIANT / _store.LP_TOKEN_BALANCE;
        _loan.liquidity = _loan.liquidity + invariantInterest;
        _store.BORROWED_INVARIANT = _store.BORROWED_INVARIANT + invariantInterest;
        _store.TOTAL_INVARIANT = _store.TOTAL_INVARIANT + invariantInterest;

        _store.LP_TOKEN_BORROWED_PLUS_INTEREST = _store.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokenInterest;
        _store.LP_TOKEN_TOTAL = _store.LP_TOKEN_TOTAL + lpTokenInterest;
    }

    function getLoanChangeData(uint256 tokenId) public virtual view returns(uint256 loanLiquidity, uint256 loanLpTokens,
        uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant,
        uint256 lpTokenBorrowed, uint256 lpTokenBalance, uint256 lpTokenBorrowedPlusInterest, uint256 lpTokenTotal) {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);

        return(_loan.liquidity, _loan.lpTokens,
            _store.BORROWED_INVARIANT, _store.LP_INVARIANT, _store.TOTAL_INVARIANT,
            _store.LP_TOKEN_BORROWED, _store.LP_TOKEN_BALANCE, _store.LP_TOKEN_BORROWED_PLUS_INTEREST, _store.LP_TOKEN_TOTAL);
    }
}
