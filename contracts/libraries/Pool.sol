pragma solidity ^0.8.0;

import "../interfaces/IProtocolModule.sol";
import "./GammaSwapLibrary.sol";

library Pool {

    uint internal constant ONE = 10**18;

    struct Info {
        address cfmm;
        IProtocolModule module;
        // the nonce for permits
        uint256[] TOKEN_BALANCE;
        uint256 LP_TOKEN_BALANCE;
        uint256 LP_TOKEN_BORROWED;
        uint256 BORROWED_INVARIANT;
        uint256 borrowRate;
        uint256 accFeeIndex;
        uint256 lastFeeIndex;
        uint256 lastCFMMFeeIndex;
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        uint256 LAST_BLOCK_NUMBER;
    }

    struct Loan {
        // the nonce for permits
        uint96 nonce;
        uint256 id;
        address operator;
        address poolId;
        uint256[] tokensHeld;
        uint256 heldLiquidity;
        uint256 liquidity;
        uint256 lpTokens;
        uint256 rateIndex;
        uint256 blockNum;
    }

    function calcTotalLPBalance(Info storage self) internal view returns(uint256 totalLPBal) {
        /*uint256 cfmmTotalInvariant = self.module.getCFMMTotalInvariant(self.cfmm);
        uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(self.cfmm);

        totalLPBal = self.LP_TOKEN_BALANCE + (self.BORROWED_INVARIANT * cfmmTotalSupply) / cfmmTotalInvariant;/**/
    }

    function calcDepositedInvariant(Info storage self, uint256 depLPBal) internal view returns(uint256 totalInvariant, uint256 depositedInvariant){
        //Info memory _self = self;
        /*uint256 cfmmTotalInvariant = self.module.getCFMMTotalInvariant(self.cfmm);
        uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(self.cfmm);

        totalInvariant = ((self.LP_TOKEN_BALANCE * cfmmTotalInvariant) / cfmmTotalSupply) + self.BORROWED_INVARIANT;
        depositedInvariant = (depLPBal * cfmmTotalInvariant) / cfmmTotalSupply;/**/
    }

    function updateIndex(Info storage self) internal {
        /*(self.lastFeeIndex, self.lastCFMMFeeIndex, self.lastCFMMInvariant, self.lastCFMMTotalSupply, self.borrowRate) = self.module
        .getCFMMYield(self.cfmm, self.lastCFMMInvariant, self.lastCFMMTotalSupply, self.LP_TOKEN_BALANCE, self.LP_TOKEN_BORROWED, self.LAST_BLOCK_NUMBER);

        self.BORROWED_INVARIANT = (self.BORROWED_INVARIANT * self.lastFeeIndex) / ONE;

        self.accFeeIndex = (self.accFeeIndex * self.lastFeeIndex) / ONE;
        self.LAST_BLOCK_NUMBER = block.number;/**/
    }

    function openLoan(Info storage self, Loan storage _loan, uint256 liquidity, uint256 lpTokens) internal {
        self.BORROWED_INVARIANT = self.BORROWED_INVARIANT + liquidity;
        self.LP_TOKEN_BORROWED = self.LP_TOKEN_BORROWED + lpTokens;
        self.LP_TOKEN_BALANCE = self.LP_TOKEN_BALANCE - lpTokens;

        _loan.liquidity = _loan.liquidity + liquidity;
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    function payLoan(Info storage self, Loan storage _loan, uint256 liquidity, uint256 lpTokensPaid) internal {
        uint256 lpTokens = (liquidity * _loan.lpTokens / _loan.liquidity);

        if(liquidity >= _loan.liquidity) {
            liquidity = _loan.liquidity;
            lpTokens = _loan.lpTokens;
        }

        self.BORROWED_INVARIANT = self.BORROWED_INVARIANT - liquidity;
        self.LP_TOKEN_BORROWED = self.LP_TOKEN_BORROWED - lpTokens;
        self.LP_TOKEN_BALANCE = self.LP_TOKEN_BALANCE + lpTokensPaid;

        _loan.liquidity = _loan.liquidity - liquidity;
        _loan.lpTokens = _loan.lpTokens - lpTokens;
    }

    function init(Info storage self, address cfmm, address module, uint numOfTokens) internal {
        self.cfmm = cfmm;
        self.module = IProtocolModule(module);
        self.TOKEN_BALANCE = new uint[](numOfTokens);
        self.accFeeIndex = 1;//
        self.lastFeeIndex = 1;//
        self.lastCFMMFeeIndex = 1;//
        self.LAST_BLOCK_NUMBER = block.number;
    }
}
