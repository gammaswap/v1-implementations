// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../cpmm/TestCPMMLongStrategy.sol";

contract TestLiquidationStrategy is TestCPMMLongStrategy {
    constructor(uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _factor, uint256 _maxApy)
        TestCPMMLongStrategy(_tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy){
    }
    
    function setLiquidity(uint256 tokenId, uint256 liquidity) public virtual {
        GammaPoolStorage.Loan storage _loan = getLoan(GammaPoolStorage.store(), tokenId);
        _loan.liquidity = liquidity;
    }

    function getSomething() public view returns(uint256) {
      GammaPoolStorage.Store storage store = GammaPoolStorage.store();
      return store.lastCFMMInvariant;
    }

    function testOpenLoan(uint256 tokenId, uint256 lpTokens) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        GammaPoolStorage.Loan storage _loan = getLoan(_store, tokenId);
        openLoan(_store, _loan, lpTokens);
    }

    function setLPTokenBalance(uint256 lpInvariant, uint256 lpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual {
        GammaPoolStorage.Store storage _store = GammaPoolStorage.store();
        _store.LP_TOKEN_BALANCE = lpTokenBalance;
        //_store.LP_TOKEN_TOTAL = lpTokenBalance;
        _store.LP_INVARIANT = lpInvariant;
        //_store.TOTAL_INVARIANT = lpInvariant;
        _store.lastCFMMInvariant = lastCFMMInvariant;
        _store.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }
}