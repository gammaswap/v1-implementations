// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../strategies/base/LongStrategy.sol";
import "../../../libraries/Math.sol";
import "../../TestCFMM.sol";
import "../../TestERC20.sol";

contract TestLongStrategy is LongStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);
    uint256 public borrowRate = 1;

    constructor() {
    }

    function initialize(address cfmm, uint24 protocolId, address protocol, address[] calldata tokens) external virtual {
        GammaPoolStorage.init(cfmm, protocolId, protocol, tokens, address(this), address(this));
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
        uint256 heldLiquidity, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex) {
        GammaPoolStorage.Loan storage _loan = getLoan(GammaPoolStorage.store(), tokenId);
        id = _loan.id;
        poolId = _loan.poolId;
        tokensHeld = _loan.tokensHeld;
        heldLiquidity = _loan.heldLiquidity;
        initLiquidity = _loan.initLiquidity;
        liquidity = _loan.liquidity;
        lpTokens = _loan.lpTokens;
        rateIndex = _loan.rateIndex;
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

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256) {
        return borrowRate;
    }

    //LongGamma
    function beforeRepay(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
        _loan.tokensHeld[0] -= amounts[0];
        _loan.tokensHeld[1] -= amounts[1];
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256 liquidity) {
        liquidity = amounts[0];
        TestCFMM(cfmm).mint(liquidity / 2, address(this));
    }

    function calcTokensToRepay(GammaPoolStorage.Store storage store, uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = liquidity;
        amounts[1] = liquidity * 2;
    }

    function squareRoot(uint256 num) public virtual pure returns(uint256) {
        return Math.sqrt(num * (10**18));
    }

    function beforeSwapTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override view returns(uint256[] memory outAmts, uint256[] memory inAmts){
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        outAmts[0] =  deltas[0] > 0 ? 0 : uint256(-deltas[0]);
        outAmts[1] =  deltas[1] > 0 ? 0 : uint256(-deltas[1]);
        inAmts[0] = deltas[0] > 0 ? uint256(deltas[0]) : 0;
        inAmts[1] = deltas[1] > 0 ? uint256(deltas[1]) : 0;
    }

    function swapTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address cfmm = store.cfmm;

        if(outAmts[0] > 0) {
            GammaSwapLibrary.safeTransfer(IERC20(store.tokens[0]), cfmm, outAmts[0]);
        } else if(outAmts[1] > 0) {
            GammaSwapLibrary.safeTransfer(IERC20(store.tokens[1]), cfmm, outAmts[1]);
        }

        if(inAmts[0] > 0) {
            TestERC20(store.tokens[0]).mint(address(this), inAmts[0]);
        } else if(inAmts[1] > 0) {
            TestERC20(store.tokens[1]).mint(address(this), inAmts[1]);
        }
    }

    //BaseStrategy
    function updateReserves(GammaPoolStorage.Store storage store) internal override virtual {
    }

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amount * 2;
        amounts[1] = amount * 4;
    }

    function testOpenLoan(uint256 tokenId, uint256 lpTokens) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);
        openLoan(_store, _loan, lpTokens);
    }

    function testPayLoan(uint256 tokenId, uint256 liquidity) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);
        payLoan(_store, _loan, liquidity);
    }

    function updateLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal override {
        //updateIndex(store);
        uint256 rateIndex = borrowRate;//(10**18);// + (10**17);
        updateLoanLiquidity(_loan, rateIndex);
    }

    function setLPTokenLoanBalance(uint256 tokenId, uint256 lpInvariant, uint256 lpTokenBalance, uint256 liquidity, uint256 lpTokens, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);

        _store.LP_INVARIANT = lpInvariant;
        _store.LP_TOKEN_BALANCE = lpTokenBalance;

        _store.BORROWED_INVARIANT = liquidity;
        _store.LP_TOKEN_BORROWED = lpTokens;
        _store.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokens;

        //_store.TOTAL_INVARIANT = _store.LP_INVARIANT + _store.BORROWED_INVARIANT;
        //_store.LP_TOKEN_TOTAL = _store.LP_TOKEN_BALANCE + _store.LP_TOKEN_BORROWED_PLUS_INTEREST;

        _store.lastCFMMInvariant = lastCFMMInvariant;
        _store.lastCFMMTotalSupply = lastCFMMTotalSupply;

        _loan.liquidity = liquidity;
        _loan.lpTokens = lpTokens;
    }

    function setLPTokenBalance(uint256 lpInvariant, uint256 lpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        _store.LP_TOKEN_BALANCE = lpTokenBalance;
        //_store.LP_TOKEN_TOTAL = lpTokenBalance;
        _store.LP_INVARIANT = lpInvariant;
        //_store.TOTAL_INVARIANT = lpInvariant;
        _store.lastCFMMInvariant = lastCFMMInvariant;
        _store.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    function chargeLPTokenInterest(uint256 tokenId, uint256 lpTokenInterest) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);

        uint256 invariantInterest = lpTokenInterest * _store.LP_INVARIANT / _store.LP_TOKEN_BALANCE;
        _loan.liquidity = _loan.liquidity + invariantInterest;
        _store.BORROWED_INVARIANT = _store.BORROWED_INVARIANT + invariantInterest;
        //_store.TOTAL_INVARIANT = _store.TOTAL_INVARIANT + invariantInterest;

        _store.LP_TOKEN_BORROWED_PLUS_INTEREST = _store.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokenInterest;
        //_store.LP_TOKEN_TOTAL = _store.LP_TOKEN_TOTAL + lpTokenInterest;
    }

    function getLoanChangeData(uint256 tokenId) public virtual view returns(uint256 loanLiquidity, uint256 loanLpTokens,
        uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant,
        uint256 lpTokenBorrowed, uint256 lpTokenBalance, uint256 lpTokenBorrowedPlusInterest,
        uint256 lpTokenTotal, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);

        return(_loan.liquidity, _loan.lpTokens,
            //_store.BORROWED_INVARIANT, _store.LP_INVARIANT, _store.TOTAL_INVARIANT,
            _store.BORROWED_INVARIANT, _store.LP_INVARIANT, (_store.BORROWED_INVARIANT + _store.LP_INVARIANT),
            _store.LP_TOKEN_BORROWED, _store.LP_TOKEN_BALANCE, _store.LP_TOKEN_BORROWED_PLUS_INTEREST,
            (_store.LP_TOKEN_BALANCE + _store.LP_TOKEN_BORROWED_PLUS_INTEREST), _store.lastCFMMInvariant, _store.lastCFMMTotalSupply);
            //_store.LP_TOKEN_TOTAL, _store.lastCFMMInvariant, _store.lastCFMMTotalSupply);
    }

    function _getCFMMPrice(address cfmm, uint256 factor) external override view returns(uint256) {
        return 1;
    }

    function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override virtual returns(uint256[] memory) {
        return new uint256[](0);
    }

    function _liquidateWithLP(uint256 tokenId) external override virtual returns(uint256[] memory) {
        return new uint256[](0);
    }
}
