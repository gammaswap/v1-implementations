// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../../strategies/cpmm/external/CPMMExternalLongStrategy.sol";

contract TestCPMMLongStrategy is CPMMExternalLongStrategy {

    using LibStorage for LibStorage.Storage;
    using Math for uint;

    error RebalanceExternally();
    error CheckLPTokens();
    error SwapExternally();
    error SendAndCalcCollateralLPTokens();
    error CalcExternalSwapFee();

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor(uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMExternalLongStrategy(10, 8000, 1e19, 2252571, _originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    function initialize(address _factory, address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        s.initialize(_factory, _cfmm, _tokens, _decimals);
    }

    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        emit LoanCreated(msg.sender, tokenId);
    }

    function setTokenBalances(uint256 tokenId, uint128 collateral0, uint128 collateral1, uint128 balance0, uint128 balance1) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        loan.tokensHeld[0] = collateral0;
        loan.tokensHeld[1] = collateral1;
        s.TOKEN_BALANCE[0] = balance0;
        s.TOKEN_BALANCE[1] = balance1;
    }

    function setCFMMReserves(uint128 reserve0, uint128 reserve1, uint128 lastCFMMInvariant) external virtual {
        s.CFMM_RESERVES[0] = reserve0;
        s.CFMM_RESERVES[1] = reserve1;
        s.lastCFMMInvariant = lastCFMMInvariant;
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
        LibStorage.Loan storage loan = s.loans[tokenId];
        (outAmts, inAmts) = beforeSwapTokens(loan, deltas, s.CFMM_RESERVES);
        emit CalcAmounts(outAmts, inAmts);
    }

    function testSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(loan, deltas, s.CFMM_RESERVES);
        swapTokens(loan, outAmts, inAmts);
        emit CalcAmounts(outAmts, inAmts);
    }

    function _decreaseCollateral(uint256, uint128[] calldata, address) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _increaseCollateral(uint256) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _rebalanceCollateral(uint256, int256[] memory, uint256[] calldata) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }

    function sendAndCalcCollateralLPTokens(address to, uint128[] calldata amounts, uint256 lastCFMMTotalSupply) internal virtual override returns(uint256 swappedCollateralAsLPTokens) {
        revert SendAndCalcCollateralLPTokens();
    }

    function externalSwap(LibStorage.Loan storage _loan, address _cfmm, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) internal override virtual returns(uint256 liquiditySwapped, uint128[] memory tokensHeld) {
        revert SwapExternally();
    }

    function calcExternalSwapFee(uint256 liquiditySwapped, uint256 loanLiquidity) internal view override virtual returns(uint256 fee) {
        revert CalcExternalSwapFee();
    }

    function _rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual returns(uint256 loanLiquidity, uint128[] memory tokensHeld) {
        revert RebalanceExternally();
    }

    function checkLPTokens(address _cfmm, uint256 prevLpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual override {
        revert CheckLPTokens();
    }

    function calcDeltasForRatio(uint256 ratio, uint128 reserve0, uint128 reserve1, uint128[] memory tokensHeld, uint256 factor, bool side) public virtual override view returns(int256[] memory deltas) {
    }
}
