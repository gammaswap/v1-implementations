// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../interfaces/external/ICPMM.sol";
import "../../libraries/Math.sol";
import "../../strategies/base/BaseStrategy.sol";

contract TestBaseStrategy is BaseStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);

    uint256 public invariant;
    uint256 public borrowRate = 10**18;
    address public _factory;
    uint16 public _protocolId;

    constructor(address factory, uint16 protocolId) {
        _factory = factory;
        _protocolId = protocolId;
    }

    function initialize(address cfmm, address[] calldata tokens) external virtual {
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

    function getParameters() public virtual view returns(address factory, address cfmm, address[] memory tokens, uint16 protocolId) {
        factory = _factory;
        cfmm = s.cfmm;
        tokens = s.tokens;
        protocolId = _protocolId;
    }

    function setUpdateStoreFields(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lpTokenBalance, uint256 borrowedInvariant, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) public virtual {
        s.accFeeIndex = accFeeIndex;
        s.lastFeeIndex = lastFeeIndex;
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.BORROWED_INVARIANT = borrowedInvariant;
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
        s.lastCFMMInvariant = lastCFMMInvariant;
    }

    function getUpdateStoreFields() public virtual view returns(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lpTokenBalance, uint256 borrowedInvariant, uint256 lastCFMMTotalSupply,
        uint256 lastCFMMInvariant, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 lpTokenTotal, uint256 totalInvariant, uint256 lastBlockNumber) {
        accFeeIndex = s.accFeeIndex;
        lastFeeIndex = s.lastFeeIndex;
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        borrowedInvariant = s.BORROWED_INVARIANT;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        lastCFMMInvariant = s.lastCFMMInvariant;

        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpInvariant = s.LP_INVARIANT;
        //lpTokenTotal = s.LP_TOKEN_TOTAL;
        lpTokenTotal = lpTokenBalance + lpTokenBorrowedPlusInterest;
        //totalInvariant = s.TOTAL_INVARIANT;
        totalInvariant = lpInvariant + borrowedInvariant;
        lastBlockNumber = s.LAST_BLOCK_NUMBER;
    }

    function setLPTokenBalAndBorrowedInv(uint256 lpTokenBal, uint256 borrowedInv) public virtual {
        s.LP_TOKEN_BALANCE = lpTokenBal;
        s.BORROWED_INVARIANT = borrowedInv;
    }

    function getLPTokenBalAndBorrowedInv() public virtual view returns(uint256 lpTokenBal, uint256 borrowedInv) {
        lpTokenBal = s.LP_TOKEN_BALANCE;
        borrowedInv = s.BORROWED_INVARIANT;
    }

    function setBorrowRate(uint256 _borrowRate) public virtual {
        borrowRate = _borrowRate;
    }

    function setLastBlockNumber(uint256 lastBlockNumber) public virtual {
        s.LAST_BLOCK_NUMBER = lastBlockNumber;
    }

    function updateLastBlockNumber() public virtual {
        s.LAST_BLOCK_NUMBER = block.number;
    }

    function getLastBlockNumber() public virtual view returns(uint256) {
        return s.LAST_BLOCK_NUMBER;
    }

    function setCFMMIndex(uint256 cfmmIndex) public virtual {
        s.lastCFMMFeeIndex = cfmmIndex;
    }

    function getCFMMIndex() public virtual view returns(uint256){
        return s.lastCFMMFeeIndex;
    }

    function testUpdateIndex() public virtual {
        updateIndex();
    }

    function getUpdateIndexFields() public virtual view returns(uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant, uint256 lastCFMMFeeIndex,
        uint256 lastFeeIndex, uint256 accFeeIndex, uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant,
        uint256 lpTokenBorrowedPlusInterest, uint256 lpTokenBal, uint256 lpTokenTotal, uint256 lastBlockNumber) {
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMFeeIndex = s.lastCFMMFeeIndex;
        lastFeeIndex = s.lastFeeIndex;
        accFeeIndex = s.accFeeIndex;
        borrowedInvariant = s.BORROWED_INVARIANT;
        lpInvariant = s.LP_INVARIANT;
        //totalInvariant = s.TOTAL_INVARIANT;
        totalInvariant = lpInvariant + borrowedInvariant;
        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpTokenBal = s.LP_TOKEN_BALANCE;
        //lpTokenTotal = s.LP_TOKEN_TOTAL;
        lpTokenTotal = lpTokenBal + lpTokenBorrowedPlusInterest;
        lastBlockNumber = s.LAST_BLOCK_NUMBER;
    }

    function testUpdateCFMMIndex() public virtual {
        updateCFMMIndex();
    }

    function testUpdateFeeIndex() public virtual {
        updateFeeIndex();
    }

    function testUpdateStore() public virtual {
        updateStore();
    }

    function setAccFeeIndex(uint256 accFeeIndex) public virtual {
        s.accFeeIndex = accFeeIndex;
    }

    function getAccFeeIndex() public virtual view returns(uint256 accFeeIndex){
        accFeeIndex = s.accFeeIndex;
    }

    function createLoan() public virtual returns(uint256 tokenId) {
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

    function getLoan(uint256 tokenId) public virtual view returns(uint256 id, address poolId, uint256[] memory tokensHeld, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex) {
        Loan storage _loan = s.loans[tokenId];
        id = _loan.id;
        poolId = _loan.poolId;
        tokensHeld = _loan.tokensHeld;
        initLiquidity = _loan.initLiquidity;
        liquidity = _loan.liquidity;
        lpTokens = _loan.lpTokens;
        rateIndex = _loan.rateIndex;
    }

    function setLoanLiquidity(uint256 tokenId, uint256 liquidity) public virtual {
        Loan storage _loan = s.loans[tokenId];
        _loan.liquidity = liquidity;
    }

    function testUpdateLoanLiquidity(uint256 tokenId, uint256 accFeeIndex) public virtual {
        Loan storage _loan = s.loans[tokenId];
        updateLoanLiquidity(_loan, accFeeIndex);
    }

    function testUpdateLoan(uint256 tokenId) public virtual {
        Loan storage _loan = s.loans[tokenId];
        updateLoan(_loan);
    }

    function getLastFeeIndex() public virtual view returns(uint256){
        return s.lastFeeIndex;
    }

    function getCFMMData() public virtual view returns(uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        lastCFMMFeeIndex = s.lastCFMMFeeIndex;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
    }

    function testMint(address account, uint256 amount) public virtual {
        _mint(account, amount);
    }

    function testBurn(address account, uint256 amount) public virtual {
        _burn(account, amount);
    }

    function totalSupply() public virtual view returns(uint256) {
        return s.totalSupply;
    }

    function balanceOf(address account) public virtual view returns(uint256) {
        return s.balanceOf[account];
    }

    function calcBorrowRate(uint256, uint256) internal virtual override view returns(uint256) {
        return borrowRate;
    }

    function getReserves() public virtual view returns(uint256[] memory) {
        return s.CFMM_RESERVES;
    }

    function testUpdateReserves() public virtual {
        updateReserves();
    }

    function updateReserves() internal virtual override {
        (s.CFMM_RESERVES[0], s.CFMM_RESERVES[1],) = ICPMM(s.cfmm).getReserves();
    }

    function setInvariant(uint256 _invariant) public virtual {
        invariant = _invariant;
    }

    function calcInvariant(address, uint256[] memory) internal virtual override view returns(uint256) {
        return invariant;
    }

    function depositToCFMM(address, uint256[] memory, address) internal virtual override returns(uint256) { return 0; }

    function withdrawFromCFMM(address, address, uint256) internal virtual override returns(uint256[] memory amounts) { return amounts; }
}
