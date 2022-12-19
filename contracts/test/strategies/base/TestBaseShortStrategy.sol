// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../interfaces/external/ICPMM.sol";
import "../../../strategies/base/ShortStrategy.sol";
import "../../TestCFMM.sol";
import "../../TestERC20.sol";

abstract contract TestBaseShortStrategy is ShortStrategy {

    using LibStorage for LibStorage.Storage;

    constructor() {
    }

    function initialize(address cfmm, address[] calldata tokens) external virtual {
        s.initialize(msg.sender, cfmm, tokens);
    }

    function setTotalSupply(uint256 _totalSupply) public virtual {
        s.totalSupply = _totalSupply;
    }

    function totalSupply() public virtual view returns (uint256) {
        return s.totalSupply;
    }

    function setTotalAssets(uint256 _totalAssets) public virtual {
        s.LP_TOKEN_BALANCE = _totalAssets;
    }

    function getTotalAssets() public virtual view returns(uint256 _totalAssets) {
        _totalAssets = s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST;
    }

    function getTotalAssetsParams() public virtual view returns(uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum,
        uint256 lpTokenTotal, uint256 lpTokenBorrowedPlusInterest) {
        borrowedInvariant = s.BORROWED_INVARIANT;
        lpBalance = s.LP_TOKEN_BALANCE;
        lpBorrowed = s.LP_TOKEN_BORROWED;
        prevCFMMInvariant = s.lastCFMMInvariant;
        prevCFMMTotalSupply = s.lastCFMMTotalSupply;
        lastBlockNum = s.LAST_BLOCK_NUMBER;
        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        //lpTokenTotal = s.LP_TOKEN_TOTAL;
        lpTokenTotal = lpBalance + lpTokenBorrowedPlusInterest;
    }

    function setLPTokenBalAndBorrowedInv(uint256 lpTokenBal, uint128 borrowedInv) public virtual {
        s.LP_TOKEN_BALANCE = lpTokenBal;
        s.BORROWED_INVARIANT = borrowedInv;
    }

    function getLPTokenBalAndBorrowedInv() public virtual view returns(uint256 lpTokenBal, uint256 borrowedInv) {
        lpTokenBal = s.LP_TOKEN_BALANCE;
        borrowedInv = s.BORROWED_INVARIANT;
    }

    function checkAllowance(address owner, address spender) public virtual view returns(uint256) {
        return s.allowance[owner][spender];
    }

    function setAllowance(address owner, address spender, uint256 amount) public virtual {
        s.allowance[owner][spender] = amount;
    }

    function spendAllowance(address owner, address spender, uint256 amount) public virtual {
        _spendAllowance(owner, spender, amount);
    }

    function withdrawAssets(address caller, address receiver, address owner, uint256 assets, uint256 shares) public virtual {
        _withdrawAssets(caller, receiver, owner, assets, shares, false);
    }

    function testUpdateIndex() public virtual {
        updateIndex();
    }

    function balanceOf(address account) public virtual view returns(uint256) {
        return s.balanceOf[account];
    }

    function depositLPTokens(address to) public virtual {
        uint256 assets = IERC20(s.cfmm).balanceOf(address(this)) - s.LP_TOKEN_BALANCE;
        uint256 shares = _convertToShares(assets);
        _mint(to, shares);
        s.LP_TOKEN_BALANCE = IERC20(s.cfmm).balanceOf(address(this));
    }

    function borrowLPTokens(uint256 lpTokens) public virtual {
        require(lpTokens < s.LP_TOKEN_BALANCE);
        TestCFMM(s.cfmm).burn(lpTokens, address(this));
        s.BORROWED_INVARIANT += uint128(TestCFMM(s.cfmm).convertSharesToInvariant(lpTokens));
        s.LP_TOKEN_BORROWED += lpTokens;
        s.LP_TOKEN_BALANCE = IERC20(s.cfmm).balanceOf(address(this));
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

        uint256 fromBalance = s.balanceOf[from];
        require(fromBalance >= amount);
        unchecked {
            s.balanceOf[from] = fromBalance - amount;
        }
        s.balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function convertToShares(uint256 assets) public view virtual returns(uint256) {
        return _convertToShares(assets);
    }

    function convertToAssets(uint256 shares) public view virtual returns(uint256) {
        return _convertToAssets(shares);
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256) {
        uint256 totalInvariant = lpInvariant + borrowedInvariant;
        return totalInvariant == 0 ? 0 : (borrowedInvariant * (10**18) / totalInvariant);
    }

    //ShortGamma
    function calcDepositAmounts(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal override virtual view returns (uint256[] memory reserves, address payee) {
        return (amountsDesired, s.cfmm);
    }

    function getReserves(address cfmm) internal override virtual view returns(uint128[] memory reserves){
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
    }

    function updateReserves(address cfmm) internal virtual override {
        (s.CFMM_RESERVES[0], s.CFMM_RESERVES[1],) = ICPMM(cfmm).getReserves();
    }

    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual override view returns(uint256) {
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
