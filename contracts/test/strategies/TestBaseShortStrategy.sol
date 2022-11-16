// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/external/ICPMM.sol";
import "../../strategies/base/ShortStrategy.sol";
import "../TestCFMM.sol";
import "../TestERC20.sol";

abstract contract TestBaseShortStrategy is ShortStrategy {

    constructor() {
    }

    function initialize(address cfmm, uint24 protocolId, address protocol, address[] calldata tokens) external virtual {
        GammaPoolStorage.init(cfmm, protocolId, protocol, tokens, address(this), address(this));
    }

    function setTotalSupply(uint256 _totalSupply) public virtual {
        GammaPoolStorage.store().totalSupply = _totalSupply;
    }

    function totalSupply() public virtual view returns (uint256) {
        return GammaPoolStorage.store().totalSupply;
    }

    function setTotalAssets(uint256 _totalAssets) public virtual {
        GammaPoolStorage.store().LP_TOKEN_TOTAL = _totalAssets;
    }

    function getTotalAssets() public virtual view returns(uint256 _totalAssets) {
        _totalAssets = GammaPoolStorage.store().LP_TOKEN_TOTAL;
    }

    function getTotalAssetsParams() public virtual view returns(uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum,
        uint256 lpTokenTotal, uint256 lpTokenBorrowedPlusInterest) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        borrowedInvariant = store.BORROWED_INVARIANT;
        lpBalance = store.LP_TOKEN_BALANCE;
        lpBorrowed = store.LP_TOKEN_BORROWED;
        prevCFMMInvariant = store.lastCFMMInvariant;
        prevCFMMTotalSupply = store.lastCFMMTotalSupply;
        lastBlockNum = store.LAST_BLOCK_NUMBER;
        lpTokenTotal = store.LP_TOKEN_TOTAL;
        lpTokenBorrowedPlusInterest = store.LP_TOKEN_BORROWED_PLUS_INTEREST;
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

    function checkAllowance(address owner, address spender) public virtual view returns(uint256) {
        return GammaPoolStorage.store().allowance[owner][spender];
    }

    function setAllowance(address owner, address spender, uint256 amount) public virtual {
        GammaPoolStorage.store().allowance[owner][spender] = amount;
    }

    function spendAllowance(address owner, address spender, uint256 amount) public virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _spendAllowance(GammaPoolStorage.store(), owner, spender, amount);
    }

    function withdrawAssets(address caller, address receiver, address owner, uint256 assets, uint256 shares) public virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _withdrawAssets(GammaPoolStorage.store(), caller, receiver, owner, assets, shares, false);
    }

    function testUpdateIndex() public virtual {
        updateIndex(GammaPoolStorage.store());
    }

    function balanceOf(address account) public virtual view returns(uint256) {
        return GammaPoolStorage.store().balanceOf[account];
    }

    function depositLPTokens(address to) public virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 assets = IERC20(store.cfmm).balanceOf(address(this)) - store.LP_TOKEN_BALANCE;
        uint256 shares = _convertToShares(store, assets);
        _mint(store, to, shares);
        store.LP_TOKEN_BALANCE = IERC20(store.cfmm).balanceOf(address(this));
    }

    function borrowLPTokens(uint256 lpTokens) public virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        require(lpTokens < store.LP_TOKEN_BALANCE);
        TestCFMM(store.cfmm).burn(lpTokens, address(this));
        store.BORROWED_INVARIANT += TestCFMM(store.cfmm).convertSharesToInvariant(lpTokens);
        store.LP_TOKEN_BORROWED += lpTokens;
        store.LP_TOKEN_BALANCE = IERC20(store.cfmm).balanceOf(address(this));
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0));
        require(to != address(0));
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        uint256 fromBalance = store.balanceOf[from];
        require(fromBalance >= amount);
        unchecked {
            store.balanceOf[from] = fromBalance - amount;
        }
        store.balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function convertToShares(uint256 assets) public view virtual returns(uint256) {
        return _convertToShares(GammaPoolStorage.store(), assets);
    }

    function convertToAssets(uint256 shares) public view virtual returns(uint256) {
        return _convertToAssets(GammaPoolStorage.store(), shares);
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256) {
        uint256 totalInvariant = lpInvariant + borrowedInvariant;
        return totalInvariant == 0 ? 0 : borrowedInvariant * (10**18) / totalInvariant;
    }

    //ShortGamma
    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal override virtual view returns (uint256[] memory reserves, address payee) {
        return (amountsDesired, store.cfmm);
    }

    function getReserves(address cfmm) internal override virtual view returns(uint256[] memory reserves){
        reserves = new uint256[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
    }

    function updateReserves(GammaPoolStorage.Store storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = ICPMM(store.cfmm).getReserves();
    }

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual override view returns(uint256) {
        return TestCFMM(cfmm).invariant();
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal override virtual returns(uint256 liquidity) {
        liquidity = amounts[0] + amounts[1];
        TestCFMM(cfmm).mint(liquidity, address(this));
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal override virtual returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount * 2;

        TestCFMM(cfmm).burn(amount, address(this));
        TestERC20(TestCFMM(cfmm).token0()).mint(to, amounts[0]);
        TestERC20(TestCFMM(cfmm).token1()).mint(to, amounts[1]);
    }
}
