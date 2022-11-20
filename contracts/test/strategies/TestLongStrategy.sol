// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../strategies/base/LongStrategy.sol";
import "../../libraries/Math.sol";
import "../TestCFMM.sol";
import "../TestERC20.sol";

contract TestLongStrategy is LongStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);
    uint256 public borrowRate = 1;
    uint16 public origFee = 0;
    uint16 public protocolId;

    constructor() {
    }

    function initialize(address cfmm, uint16 _protocolId, address[] calldata tokens) external virtual {
        protocolId = _protocolId;
        s.cfmm = cfmm;
        s.tokens = tokens;
        s.factory = msg.sender;
        s.TOKEN_BALANCE = new uint256[](tokens.length);
        s.CFMM_RESERVES = new uint256[](tokens.length);

        s.accFeeIndex = 10**18;
        s.lastFeeIndex = 10**18;
        s.lastCFMMFeeIndex = 10**18;
        s.LAST_BLOCK_NUMBER = block.number;
        s.nextId = 1;
        s.unlocked = 1;
        s.ONE = 10**18;
    }

    function tokens() public virtual view returns(address[] memory) {
        return s.tokens;
    }

    function tokenBalances() public virtual view returns(uint256[] memory) {
        return s.TOKEN_BALANCE;
    }

    // **** LONG GAMMA **** //
    function createLoan() external virtual returns(uint256 tokenId) {
        uint256 id = s.nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        s.loans[tokenId] = Loan({
            id: id,
            poolId: address(this),
            tokensHeld: new uint[](s.tokens.length),
            heldLiquidity: 0,
            initLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            rateIndex: s.accFeeIndex
        });
        emit LoanCreated(msg.sender, tokenId);
    }

    function getLoan(uint256 tokenId) public virtual view returns(uint256 id, address poolId, uint256[] memory tokensHeld,
        uint256 heldLiquidity, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex) {
        Loan storage _loan = _getLoan(tokenId);
        id = _loan.id;
        poolId = _loan.poolId;
        tokensHeld = _loan.tokensHeld;
        heldLiquidity = calcInvariant(s.cfmm, _loan.tokensHeld);
        initLiquidity = _loan.initLiquidity;
        liquidity = _loan.liquidity;
        lpTokens = _loan.lpTokens;
        rateIndex = _loan.rateIndex;
    }

    function setLiquidity(uint256 tokenId, uint256 liquidity) public virtual {
        Loan storage _loan = _getLoan(tokenId);
        _loan.liquidity = liquidity;
    }

    function setHeldAmounts(uint256 tokenId, uint256[] calldata heldAmounts) public virtual {
        Loan storage _loan = _getLoan(tokenId);
        _loan.tokensHeld = heldAmounts;
    }

    function checkMargin(uint256 tokenId, uint24 limit) public virtual view returns(bool) {
        Loan storage _loan = _getLoan(tokenId);
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
    function beforeRepay(Loan storage _loan, uint256[] memory amounts) internal virtual override {
        _loan.tokensHeld[0] -= amounts[0];
        _loan.tokensHeld[1] -= amounts[1];
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256 liquidity) {
        liquidity = amounts[0];
        TestCFMM(cfmm).mint(liquidity / 2, address(this));
    }

    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = liquidity;
        amounts[1] = liquidity * 2;
    }

    function squareRoot(uint256 num) public virtual pure returns(uint256) {
        return Math.sqrt(num * (10**18));
    }

    function beforeSwapTokens(Loan storage _loan, int256[] calldata deltas) internal virtual override view returns(uint256[] memory outAmts, uint256[] memory inAmts){
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        outAmts[0] =  deltas[0] > 0 ? 0 : uint256(-deltas[0]);
        outAmts[1] =  deltas[1] > 0 ? 0 : uint256(-deltas[1]);
        inAmts[0] = deltas[0] > 0 ? uint256(deltas[0]) : 0;
        inAmts[1] = deltas[1] > 0 ? uint256(deltas[1]) : 0;
    }

    function swapTokens(Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address cfmm = s.cfmm;

        if(outAmts[0] > 0) {
            GammaSwapLibrary.safeTransfer(IERC20(s.tokens[0]), cfmm, outAmts[0]);
        } else if(outAmts[1] > 0) {
            GammaSwapLibrary.safeTransfer(IERC20(s.tokens[1]), cfmm, outAmts[1]);
        }

        if(inAmts[0] > 0) {
            TestERC20(s.tokens[0]).mint(address(this), inAmts[0]);
        } else if(inAmts[1] > 0) {
            TestERC20(s.tokens[1]).mint(address(this), inAmts[1]);
        }
    }

    //BaseStrategy
    function updateReserves() internal override virtual {
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
        openLoan(_getLoan(tokenId), lpTokens);
    }

    function testPayLoan(uint256 tokenId, uint256 liquidity) public virtual {
        Loan storage _loan = _getLoan(tokenId);
        payLoan(_loan, liquidity);
    }

    function updateLoan(Loan storage _loan) internal override {
        //updateIndex(store);
        uint256 rateIndex = borrowRate;//(10**18);// + (10**17);
        updateLoanLiquidity(_loan, rateIndex);
    }

    function setLPTokenLoanBalance(uint256 tokenId, uint256 lpInvariant, uint256 lpTokenBalance, uint256 liquidity, uint256 lpTokens, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual {
        Loan storage _loan = _getLoan(tokenId);

        s.LP_INVARIANT = lpInvariant;
        s.LP_TOKEN_BALANCE = lpTokenBalance;

        s.BORROWED_INVARIANT = liquidity;
        s.LP_TOKEN_BORROWED = lpTokens;
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokens;

        //s.TOTAL_INVARIANT = s.LP_INVARIANT + s.BORROWED_INVARIANT;
        //s.LP_TOKEN_TOTAL = s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST;

        s.lastCFMMInvariant = lastCFMMInvariant;
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;

        _loan.liquidity = liquidity;
        _loan.lpTokens = lpTokens;
    }

    function setLPTokenBalance(uint256 lpInvariant, uint256 lpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual {
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        //s.LP_TOKEN_TOTAL = lpTokenBalance;
        s.LP_INVARIANT = lpInvariant;
        //s.TOTAL_INVARIANT = lpInvariant;
        s.lastCFMMInvariant = lastCFMMInvariant;
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    function chargeLPTokenInterest(uint256 tokenId, uint256 lpTokenInterest) public virtual {
        Loan storage _loan = _getLoan(tokenId);

        uint256 invariantInterest = lpTokenInterest * s.LP_INVARIANT / s.LP_TOKEN_BALANCE;
        _loan.liquidity = _loan.liquidity + invariantInterest;
        s.BORROWED_INVARIANT = s.BORROWED_INVARIANT + invariantInterest;
        //s.TOTAL_INVARIANT = s.TOTAL_INVARIANT + invariantInterest;

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokenInterest;
        //s.LP_TOKEN_TOTAL = s.LP_TOKEN_TOTAL + lpTokenInterest;
    }

    function getLoanChangeData(uint256 tokenId) public virtual view returns(uint256 loanLiquidity, uint256 loanLpTokens,
        uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant,
        uint256 lpTokenBorrowed, uint256 lpTokenBalance, uint256 lpTokenBorrowedPlusInterest,
        uint256 lpTokenTotal, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        Loan storage _loan = _getLoan(tokenId);

        return(_loan.liquidity, _loan.lpTokens,
            //s.BORROWED_INVARIANT, s.LP_INVARIANT, s.TOTAL_INVARIANT,
            s.BORROWED_INVARIANT, s.LP_INVARIANT, (s.BORROWED_INVARIANT + s.LP_INVARIANT),
            s.LP_TOKEN_BORROWED, s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED_PLUS_INTEREST,
            (s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST), s.lastCFMMInvariant, s.lastCFMMTotalSupply);
            //s.LP_TOKEN_TOTAL, s.lastCFMMInvariant, s.lastCFMMTotalSupply);
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

    function setOriginationFee(uint16 _origFee) external virtual {
        origFee = _origFee;
    }

    function originationFee() internal override virtual view returns(uint16) {
        return origFee;
    }
}
