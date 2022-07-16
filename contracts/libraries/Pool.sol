pragma solidity ^0.8.0;

import "../interfaces/IProtocolModule.sol";
import "./GammaSwapLibrary.sol";

library Pool {

    uint internal constant ONE = 10**18;

    struct Info {
        address cfmm;
        IProtocolModule module;
        // the nonce for permits
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

    //function updateBorrowRate(Info storage self) public {
        //Info memory _self = self;
        //borrowRate = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol)).calcBorrowRate(LP_TOKEN_BALANCE, LP_TOKEN_BORROWED);
    //    self.borrowRate = self.module.calcBorrowRate(self.LP_TOKEN_BALANCE, self.LP_TOKEN_BORROWED);
    //}

    function openLoan(Info storage self, uint256 liquidity, uint256 lpTokens) internal {
        self.BORROWED_INVARIANT = self.BORROWED_INVARIANT + liquidity;
        self.LP_TOKEN_BORROWED = self.LP_TOKEN_BORROWED + lpTokens;
        self.LP_TOKEN_BALANCE = self.LP_TOKEN_BALANCE - lpTokens;
    }

    function payLoan(Info storage self, uint256 liquidity, uint256 lpTokens, uint256 lpTokensPaid) internal {
        self.BORROWED_INVARIANT = self.BORROWED_INVARIANT - liquidity;
        self.LP_TOKEN_BORROWED = self.LP_TOKEN_BORROWED - lpTokens;
        self.LP_TOKEN_BALANCE = self.LP_TOKEN_BALANCE + lpTokensPaid;
    }

    function calcTotalLPBalance(Info storage self) public view returns(uint256 totalLPBal) {
        uint256 cfmmTotalInvariant = self.module.getCFMMTotalInvariant(self.cfmm);
        uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(self.cfmm);

        totalLPBal = self.LP_TOKEN_BALANCE + (self.BORROWED_INVARIANT * cfmmTotalSupply) / cfmmTotalInvariant;
    }

    function calcDepositedInvariant(Info storage self, uint256 depLPBal) public view returns(uint256 totalInvariant, uint256 depositedInvariant){
        //Info memory _self = self;
        uint256 cfmmTotalInvariant = self.module.getCFMMTotalInvariant(self.cfmm);
        uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(self.cfmm);

        totalInvariant = ((self.LP_TOKEN_BALANCE * cfmmTotalInvariant) / cfmmTotalSupply) + self.BORROWED_INVARIANT;
        depositedInvariant = (depLPBal * cfmmTotalInvariant) / cfmmTotalSupply;
    }

    function updateIndex(Info storage self) internal {
        //Info storage _self = self;

        //(self.lastFeeIndex, self.lastCFMMFeeIndex, self.lastCFMMInvariant, self.lastCFMMTotalSupply) = IProtocolModule(_self.module)
        //    .getCFMMYield(_self.cfmm, _self.lastCFMMInvariant, _self.lastCFMMTotalSupply, _self.borrowRate, _self.LAST_BLOCK_NUMBER);

        (self.lastFeeIndex, self.lastCFMMFeeIndex, self.lastCFMMInvariant, self.lastCFMMTotalSupply) = self.module
        .getCFMMYield(self.cfmm, self.lastCFMMInvariant, self.lastCFMMTotalSupply, self.borrowRate, self.LAST_BLOCK_NUMBER);

        self.BORROWED_INVARIANT = (self.BORROWED_INVARIANT * self.lastFeeIndex) / ONE;

        self.accFeeIndex = (self.accFeeIndex * self.lastFeeIndex) / ONE;
        self.LAST_BLOCK_NUMBER = block.number;
    }

    function init(Info storage self, address cfmm, address module) public {
        self.cfmm = cfmm;
        self.module = IProtocolModule(module);
        self.LP_TOKEN_BALANCE = 0;//
        self.LP_TOKEN_BORROWED = 0;//
        self.BORROWED_INVARIANT = 0;//
        self.borrowRate = 0;//
        self.accFeeIndex = 1;//
        self.lastFeeIndex = 1;//
        self.lastCFMMFeeIndex = 1;//
        self.lastCFMMInvariant = 0;//
        self.lastCFMMTotalSupply = 0;//
        self.LAST_BLOCK_NUMBER = block.number;
    }
}
