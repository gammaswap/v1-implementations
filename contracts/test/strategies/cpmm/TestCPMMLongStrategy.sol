// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/cpmm/CPMMLongStrategy.sol";

contract TestCPMMLongStrategy is CPMMLongStrategy {

    using Math for uint;

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor(uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _factor, uint256 _maxApy)
        CPMMLongStrategy(_originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
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

    function cfmm() public view returns(address) {
        return s.cfmm;
    }

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

    function setTokenBalances(uint256 tokenId, uint256 collateral0, uint256 collateral1, uint256 balance0, uint256 balance1) external virtual {
        Loan storage loan = s.loans[tokenId];
        loan.tokensHeld[0] = collateral0;
        loan.tokensHeld[1] = collateral1;
        s.TOKEN_BALANCE[0] = balance0;
        s.TOKEN_BALANCE[1] = balance1;
    }

    function setCFMMReserves(uint256 reserve0, uint256 reserve1, uint256 lastCFMMInvariant) external virtual {
        s.CFMM_RESERVES[0] = reserve0;
        s.CFMM_RESERVES[1] = reserve1;
        s.lastCFMMInvariant = lastCFMMInvariant;
    }

    function testCalcTokensToRepay(uint256 liquidity) external virtual view returns(uint256, uint256) {
        uint256[] memory amounts;
        amounts = calcTokensToRepay(liquidity);
        return(amounts[0], amounts[1]);
    }

    function testBeforeRepay(uint256 tokenId, uint256[] memory amounts) external virtual {
        beforeRepay(s.loans[tokenId], amounts);
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
        Loan storage loan = s.loans[tokenId];
        (outAmts, inAmts) = beforeSwapTokens(loan, deltas);
        emit CalcAmounts(outAmts, inAmts);
    }

    function testSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual {
        Loan storage loan = s.loans[tokenId];
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(loan, deltas);
        swapTokens(loan, outAmts, inAmts);
        emit CalcAmounts(outAmts, inAmts);
    }

    function updateCollateral(Loan storage _loan) internal override virtual {

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

    function payLoanAndRefundLiquidator(uint256 tokenId, Loan storage _loan) internal override virtual returns(uint256[] memory refund) {
        return new uint256[](0);
    }
}
