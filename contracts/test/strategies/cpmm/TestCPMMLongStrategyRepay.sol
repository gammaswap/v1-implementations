// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../../strategies/cpmm/external/CPMMExternalLongStrategy.sol";

contract TestCPMMLongStrategyRepay is CPMMExternalLongStrategy {

    using LibStorage for LibStorage.Storage;
    using Math for uint;

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor(uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMExternalLongStrategy(10, 8000, 1e19, 2252571, _originationFee, _tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    function initialize(address _factory, address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        s.initialize(_factory, _cfmm, _tokens, _decimals);
    }

    function testCalcTokensToRepay(uint256 liquidity) external virtual view returns(uint256, uint256) {
        uint256[] memory amounts = calcTokensToRepay(s.CFMM_RESERVES, liquidity);
        return(amounts[0], amounts[1]);
    }

    function testCalcInvariant(uint128[] calldata reserves) external virtual view returns(uint256) {
        return calcInvariant(address(0),reserves);
    }

    function testBeforeRepay(uint256 tokenId, uint256[] memory amounts) external virtual {
        beforeRepay(s.loans[tokenId], amounts);
    }

    function getLoan(uint256 tokenId) external virtual view returns(LibStorage.Loan memory _loan) {
        _loan = s.loans[tokenId];
    }

    function depositLPTokens(uint256 tokenId) external virtual {
        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        updateIndex();
        updateCollateral(s.loans[tokenId]);
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));
        uint128 lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.LP_INVARIANT = lpInvariant;
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

    function _decreaseCollateral(uint256, uint128[] calldata, address) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _increaseCollateral(uint256) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _rebalanceCollateral(uint256, int256[] memory, uint256[] calldata) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }
}
