// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../strategies/cpmm/lending/CPMMBorrowStrategy.sol";

contract TestCPMMBorrowStrategy is CPMMBorrowStrategy {

    using LibStorage for LibStorage.Storage;
    using GSMath for uint;

    error RebalanceExternally();
    error CheckLPTokens();
    error SwapExternally();
    error SendAndCalcCollateralLPTokens();
    error CalcExternalSwapFee();

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor(address mathLib_, uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_,
        uint80 maxApy_) CPMMBorrowStrategy(mathLib_, 1e19, 2252571, tradingFee1_, tradingFee2_, baseRate_,
        factor_, maxApy_) {
    }

    function initialize(address _factory, address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        s.initialize(_factory, _cfmm, 1, _tokens, _decimals);
        s.origFee = 0;
    }

    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);
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
        uint256 actualOutAmount = calcActualOutAmt(token, to, amount, balance, collateral);
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

    function _decreaseCollateral(uint256, uint128[] memory, address, uint256[] calldata) external virtual override returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _increaseCollateral(uint256, uint256[] calldata) external virtual override returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _rebalanceCollateral(uint256, int256[] memory, uint256[] calldata) external virtual override returns(uint128[] memory) {
        return new uint128[](2);
    }
}
