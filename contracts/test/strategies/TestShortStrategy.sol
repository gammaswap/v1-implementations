// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/external/ICPMM.sol";
import "../../strategies/base/ShortStrategy.sol";

contract TestShortStrategy is ShortStrategy {

    uint256 public invariant;
    uint256 public borrowRate = 10**18;

    constructor() {
        GammaPoolStorage.init();
    }

    function setTotalSupply(uint256 _totalSupply) public virtual {
        GammaPoolStorage.store().totalSupply = _totalSupply;
    }

    function totalSupply() public virtual view returns (uint256){
        return GammaPoolStorage.store().totalSupply;
    }

    function setTotalAssets(uint256 _totalAssets) public virtual {
        GammaPoolStorage.store().LP_TOKEN_TOTAL = _totalAssets;
    }

    function getTotalAssets() public virtual view returns(uint256 _totalAssets) {
        _totalAssets = GammaPoolStorage.store().LP_TOKEN_TOTAL;
    }

    function getTotalAssetsParams() public virtual view returns(uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        borrowedInvariant = store.BORROWED_INVARIANT;
        lpBalance = store.LP_TOKEN_BALANCE;
        lpBorrowed = store.LP_TOKEN_BORROWED;
        prevCFMMInvariant = store.lastCFMMInvariant;
        prevCFMMTotalSupply = store.lastCFMMTotalSupply;
        lastBlockNum = store.LAST_BLOCK_NUMBER;
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

    function testUpdateIndex() public virtual {
        updateIndex(GammaPoolStorage.store());
    }



    function convertToShares(uint256 assets) public view virtual returns(uint256) {
        return _convertToShares(GammaPoolStorage.store(), assets);
    }

    function convertToAssets(uint256 shares) public view virtual returns(uint256) {
        return _convertToAssets(GammaPoolStorage.store(), shares);
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return _previewDeposit(GammaPoolStorage.store(), assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return _previewMint(GammaPoolStorage.store(), shares);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return _previewWithdraw(GammaPoolStorage.store(), assets);
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _previewRedeem(GammaPoolStorage.store(), shares);
    }


    function calcBorrowRate(uint256, uint256) internal virtual override view returns(uint256) {
        return borrowRate;
    }

    //ShortGamma
    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal override virtual returns (uint256[] memory reserves, address payee) {
        return (reserves, payee);
    }

    function getReserves(address cfmm) internal override virtual view returns(uint256[] memory reserves){
        reserves = new uint256[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
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

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal override virtual returns(uint256 liquidity) {
        return liquidity;
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal override virtual returns(uint256[] memory amounts) { return amounts; }
}
