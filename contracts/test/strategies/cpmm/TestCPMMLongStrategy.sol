// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/cpmm/CPMMLongStrategy.sol";

contract TestCPMMLongStrategy is CPMMLongStrategy {

    using Math for uint;

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor() {
        GammaPoolStorage.init();
        CPMMStrategyStorage.init(msg.sender, 0, 997, 1000);
    }

    function cfmm() public view returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    function createLoan() external virtual {
        uint256 tokenId = GammaPoolStorage.createLoan();
        emit LoanCreated(msg.sender, tokenId);
    }

    function setTokenBalances(uint256 tokenId, uint256 collateral0, uint256 collateral1, uint256 balance0, uint256 balance1) external virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage loan = store.loans[tokenId];
        loan.tokensHeld[0] = collateral0;
        loan.tokensHeld[1] = collateral1;
        store.TOKEN_BALANCE[0] = balance0;
        store.TOKEN_BALANCE[1] = balance1;
    }

    function setCFMMReserves(uint256 reserve0, uint256 reserve1, uint256 lastCFMMInvariant) external virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        store.CFMM_RESERVES[0] = reserve0;
        store.CFMM_RESERVES[1] = reserve1;
        store.lastCFMMInvariant = lastCFMMInvariant;
    }

    function testCalcTokensToRepay(uint256 liquidity) external virtual view returns(uint256, uint256) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256[] memory amounts;
        amounts = calcTokensToRepay(store, liquidity);
        return(amounts[0], amounts[1]);
    }

    function testBeforeRepay(uint256 tokenId, uint256[] memory amounts) external virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage loan = store.loans[tokenId];
        beforeRepay(store, loan, amounts);
    }

    // selling exactly amountOut
    function testCalcAmtIn(uint256 amountOut, uint256 reserveOut, uint256 reserveIn) external virtual view returns (uint256) {
        return calcAmtIn(amountOut, reserveOut, reserveIn);
    }

    // buying exactly amountIn
    function testCalcAmtOut(uint256 amountIn, uint256 reserveOut, uint256 reserveIn) external virtual view returns (uint256) {
        return calcAmtOut(amountIn, reserveOut, reserveIn);
    }

    function testCalcActualOutAmount(address token, address to, uint256 amount, uint256 balance, uint256 collateral) external virtual {
        uint256 actualOutAmount = calcActualOutAmt(IERC20(token), to, amount, balance, collateral);
        emit ActualOutAmount(actualOutAmount);
    }

    function testBeforeSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage loan = store.loans[tokenId];
        (outAmts, inAmts) = beforeSwapTokens(store, loan, deltas);
        emit CalcAmounts(outAmts, inAmts);
    }

    function testSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage loan = store.loans[tokenId];
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(store, loan, deltas);
        swapTokens(store, loan, outAmts, inAmts);
        emit CalcAmounts(outAmts, inAmts);
    }

    function updateCollateral(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal override virtual {

    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256[] memory amounts) {

    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {

    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override returns(uint256[] memory val) {
    }

    function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override virtual returns(uint256[] memory) {
        return new uint256[](0);
    }

    function _liquidateWithLP(uint256 tokenId) external override virtual returns(uint256[] memory) {
        return new uint256[](0);
    }

    function payLoanAndRefundLiquidator(uint256 tokenId, GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal override virtual returns(uint256[] memory refund) {
        return new uint256[](0);
    }
}
