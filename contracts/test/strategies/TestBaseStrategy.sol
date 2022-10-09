// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/external/ICPMM.sol";
import "../../libraries/Math.sol";
import "../../strategies/base/BaseStrategy.sol";

contract TestBaseStrategy is BaseStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);

    uint256 public invariant;
    uint256 public borrowRate = 10**18;

    constructor() {
        GammaPoolStorage.init();
    }

    function getParameters() public virtual view returns(address factory, address cfmm, address[] memory tokens, uint24 protocolId, address protocol) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        factory = store.factory;
        cfmm = store.cfmm;
        tokens = store.tokens;
        protocolId = store.protocolId;
        protocol = store.protocol;
    }

    function setUpdateStoreFields(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lpTokenBalance, uint256 borrowedInvariant, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) public virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        store.accFeeIndex = accFeeIndex;
        store.lastFeeIndex = lastFeeIndex;
        store.LP_TOKEN_BALANCE = lpTokenBalance;
        store.BORROWED_INVARIANT = borrowedInvariant;
        store.lastCFMMTotalSupply = lastCFMMTotalSupply;
        store.lastCFMMInvariant = lastCFMMInvariant;
    }

    function getUpdateStoreFields() public virtual view returns(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lpTokenBalance, uint256 borrowedInvariant, uint256 lastCFMMTotalSupply,
        uint256 lastCFMMInvariant, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 lpTokenTotal, uint256 totalInvariant, uint256 lastBlockNumber) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        accFeeIndex = store.accFeeIndex;
        lastFeeIndex = store.lastFeeIndex;
        lpTokenBalance = store.LP_TOKEN_BALANCE;
        borrowedInvariant = store.BORROWED_INVARIANT;
        lastCFMMTotalSupply = store.lastCFMMTotalSupply;
        lastCFMMInvariant = store.lastCFMMInvariant;

        lpTokenBorrowedPlusInterest = store.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpInvariant = store.LP_INVARIANT;
        lpTokenTotal = store.LP_TOKEN_TOTAL;
        totalInvariant = store.TOTAL_INVARIANT;
        lastBlockNumber = store.LAST_BLOCK_NUMBER;
    }

    function setLPTokenBalAndBorrowedInv(uint256 lpTokenBal, uint256 borrowedInv) public virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        store.LP_TOKEN_BALANCE = lpTokenBal;
        store.BORROWED_INVARIANT = borrowedInv;
    }

    function getLPTokenBalAndBorrowedInv() public virtual view returns(uint256 lpTokenBal, uint256 borrowedInv) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        lpTokenBal = store.LP_TOKEN_BALANCE;
        borrowedInv = store.BORROWED_INVARIANT;
    }

    function setBorrowRate(uint256 _borrowRate) public virtual {
        borrowRate = _borrowRate;
    }

    function setLastBlockNumber(uint256 lastBlockNumber) public virtual {
        GammaPoolStorage.store().LAST_BLOCK_NUMBER = lastBlockNumber;
    }

    function updateLastBlockNumber() public virtual {
        GammaPoolStorage.store().LAST_BLOCK_NUMBER = block.number;
    }

    function getLastBlockNumber() public virtual view returns(uint256) {
        return GammaPoolStorage.store().LAST_BLOCK_NUMBER;
    }

    function setCFMMIndex(uint256 cfmmIndex) public virtual {
        GammaPoolStorage.store().lastCFMMFeeIndex = cfmmIndex;
    }

    function getCFMMIndex() public virtual view returns(uint256){
        return GammaPoolStorage.store().lastCFMMFeeIndex;
    }

    function testUpdateIndex() public virtual {
        updateIndex(GammaPoolStorage.store());
    }

    function getUpdateIndexFields() public virtual view returns(uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant, uint256 lastCFMMFeeIndex,
        uint256 lastFeeIndex, uint256 accFeeIndex, uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant,
        uint256 lpTokenBorrowedPlusInterest, uint256 lpTokenBal, uint256 lpTokenTotal, uint256 lastBlockNumber) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        lastCFMMTotalSupply = store.lastCFMMTotalSupply;
        lastCFMMInvariant = store.lastCFMMInvariant;
        lastCFMMFeeIndex = store.lastCFMMFeeIndex;
        lastFeeIndex = store.lastFeeIndex;
        accFeeIndex = store.accFeeIndex;
        borrowedInvariant = store.BORROWED_INVARIANT;
        lpInvariant = store.LP_INVARIANT;
        totalInvariant = store.TOTAL_INVARIANT;
        lpTokenBorrowedPlusInterest = store.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpTokenBal = store.LP_TOKEN_BALANCE;
        lpTokenTotal = store.LP_TOKEN_TOTAL;
        lastBlockNumber = store.LAST_BLOCK_NUMBER;
    }

    function testUpdateCFMMIndex() public virtual {
        updateCFMMIndex(GammaPoolStorage.store());
    }

    function testUpdateFeeIndex() public virtual {
        updateFeeIndex(GammaPoolStorage.store());
    }

    function testUpdateStore() public virtual {
        updateStore(GammaPoolStorage.store());
    }

    function setAccFeeIndex(uint256 accFeeIndex) public virtual {
        GammaPoolStorage.store().accFeeIndex = accFeeIndex;
    }

    function getAccFeeIndex() public virtual view returns(uint256 accFeeIndex){
        accFeeIndex = GammaPoolStorage.store().accFeeIndex;
    }

    function createLoan() public virtual returns(uint256 tokenId) {
        tokenId = GammaPoolStorage.createLoan();
        emit LoanCreated(msg.sender, tokenId);
    }

    function getLoan(uint256 tokenId) public virtual view returns(uint256 id, address poolId, uint256[] memory tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex, uint256 blockNum) {
        GammaPoolStorage.Loan storage _loan = GammaPoolStorage.store().loans[tokenId];
        id = _loan.id;
        poolId = _loan.poolId;
        tokensHeld = _loan.tokensHeld;
        liquidity = _loan.liquidity;
        lpTokens = _loan.lpTokens;
        rateIndex = _loan.rateIndex;
        blockNum = _loan.blockNum;
    }

    function setLoanLiquidity(uint256 tokenId, uint256 liquidity) public virtual {
        GammaPoolStorage.Loan storage _loan = GammaPoolStorage.store().loans[tokenId];
        _loan.liquidity = liquidity;
    }

    function testUpdateLoanLiquidity(uint256 tokenId, uint256 accFeeIndex) public virtual {
        GammaPoolStorage.Loan storage _loan = GammaPoolStorage.store().loans[tokenId];
        updateLoanLiquidity(_loan, accFeeIndex);
    }

    function testUpdateLoan(uint256 tokenId) public virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = store.loans[tokenId];
        updateLoan(store, _loan);
    }

    function getLastFeeIndex() public virtual view returns(uint256){
        return GammaPoolStorage.store().lastFeeIndex;
    }

    function getCFMMData() public virtual view returns(uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        lastCFMMFeeIndex = store.lastCFMMFeeIndex;
        lastCFMMInvariant = store.lastCFMMInvariant;
        lastCFMMTotalSupply = store.lastCFMMTotalSupply;
    }

    function testMint(address account, uint256 amount) public virtual {
        _mint(GammaPoolStorage.store(), account, amount);
    }

    function testBurn(address account, uint256 amount) public virtual {
        _burn(GammaPoolStorage.store(), account, amount);
    }

    function totalSupply() public virtual view returns(uint256) {
        return GammaPoolStorage.store().totalSupply;
    }

    function balanceOf(address account) public virtual view returns(uint256) {
        return GammaPoolStorage.store().balanceOf[account];
    }

    function calcBorrowRate(uint256, uint256) internal virtual override view returns(uint256) {
        return borrowRate;
    }

    function getReserves() public virtual view returns(uint256[] memory) {
        return GammaPoolStorage.store().CFMM_RESERVES;
    }

    function testUpdateReserves() public virtual {
        updateReserves(GammaPoolStorage.store());
    }

    function updateReserves(GammaPoolStorage.Store storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = ICPMM(store.cfmm).getReserves();
    }

    function setInvariant(uint256 _invariant) public virtual {
        invariant = _invariant;
    }

    function calcInvariant(address, uint256[] memory) internal virtual override view returns(uint256) {
        return invariant;
    }


    function preDepositToCFMM(GammaPoolStorage.Store storage store, uint256[] memory amounts, address to, bytes memory data) internal virtual override {
    }

    function depositToCFMM(address, uint256[] memory, address) internal virtual override returns(uint256) { return 0; }

    function withdrawFromCFMM(address, address, uint256) internal virtual override returns(uint256[] memory amounts) { return amounts; }
}
