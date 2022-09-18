// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@gammaswap/v1-core/contracts/libraries/storage/GammaPoolStorage.sol";

import "../../libraries/GammaSwapLibrary.sol";
import "../../interfaces/rates/AbstractRateModel.sol";

abstract contract BaseStrategy is AbstractRateModel {

    event Transfer(address indexed from, address indexed to, uint256 value);

    function updateReserves(GammaPoolStorage.Store storage store) internal virtual;

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual view returns(uint256);

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual returns(uint256 liquidity);

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual returns(uint256[] memory amounts);

    function updateIndex(GammaPoolStorage.Store storage store) internal virtual {
        uint256 ONE = store.ONE;
        store.borrowRate = calcBorrowRate(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED);
        {
            updateReserves(store);
            uint256 lastCFMMInvariant = calcInvariant(store.cfmm, store.CFMM_RESERVES);
            uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(store.cfmm);
            if(lastCFMMTotalSupply > 0) {
                uint256 denominator = (store.lastCFMMInvariant * lastCFMMTotalSupply) / ONE;
                store.lastCFMMFeeIndex = (lastCFMMInvariant * store.lastCFMMTotalSupply) / denominator;
            } else {
                store.lastCFMMFeeIndex = ONE;
            }
            store.lastCFMMInvariant = lastCFMMInvariant;
            store.lastCFMMTotalSupply = lastCFMMTotalSupply;
        }

        {
            uint256 blockDiff = block.number - store.LAST_BLOCK_NUMBER;
            uint256 adjBorrowRate = (blockDiff * store.borrowRate) / 2252571;//2252571 year block count
            store.lastFeeIndex = store.lastCFMMFeeIndex + adjBorrowRate;
        }

        store.BORROWED_INVARIANT = (store.BORROWED_INVARIANT * store.lastFeeIndex) / ONE;

        store.LP_TOKEN_BORROWED_PLUS_INTEREST = (store.BORROWED_INVARIANT * store.lastCFMMTotalSupply ) / store.lastCFMMInvariant;
        store.LP_INVARIANT = (store.LP_TOKEN_BALANCE * store.lastCFMMInvariant) / store.lastCFMMTotalSupply;
        store.LP_TOKEN_TOTAL = store.LP_TOKEN_BALANCE + store.LP_TOKEN_BORROWED_PLUS_INTEREST;
        store.TOTAL_INVARIANT = store.LP_INVARIANT + store.BORROWED_INVARIANT;

        store.accFeeIndex = (store.accFeeIndex * store.lastFeeIndex) / ONE;
        store.LAST_BLOCK_NUMBER = block.number;

        if(store.BORROWED_INVARIANT > 0) {
            (address feeTo, uint256 devFee) = IGammaPoolFactory(store.factory).feeInfo();
            if(feeTo != address(0) && devFee > 0) {
                 //Formula:
                 //        accumulatedGrowth: (1 - [borrowedInvariant/(borrowedInvariant*index)])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
                 //        accumulatedGrowth: (1 - [1/index])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
                 //        sharesToIssue: totalGammaTokenSupply*accGrowth/(1-accGrowth)
                uint256 totalInvariantInCFMM = ((store.LP_TOKEN_BALANCE * store.lastCFMMInvariant) / store.lastCFMMTotalSupply);//How much Invariant does this contract have from LP_TOKEN_BALANCE
                //uint256 factor = ((store.lastFeeIndex - (10**18)) * devFee) / store.lastFeeIndex;//Percentage of the current growth that we will give to devs
                uint256 factor = ((store.lastFeeIndex - ONE) * devFee) / store.lastFeeIndex;//Percentage of the current growth that we will give to devs
                uint256 accGrowth = (factor * store.BORROWED_INVARIANT) / (store.BORROWED_INVARIANT + totalInvariantInCFMM);
                //_mint(store, feeTo, (store.totalSupply * accGrowth) / ((10**18) - accGrowth));
                _mint(store, feeTo, (store.totalSupply * accGrowth) / (ONE - accGrowth));
            }
        }
    }

    function updateLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal {
        updateIndex(store);
        _loan.liquidity = (_loan.liquidity * store.accFeeIndex) / _loan.rateIndex;
        _loan.rateIndex = store.accFeeIndex;
    }

    function _mint(GammaPoolStorage.Store storage store, address account, uint256 amount) internal virtual {
        require(amount > 0, '0 amt');
        store.totalSupply += amount;
        store.balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(GammaPoolStorage.Store storage store, address account, uint256 amount) internal virtual {
        require(account != address(0), "0 address");
        uint256 accountBalance = store.balanceOf[account];
        require(accountBalance >= amount, "> balance");
        unchecked {
            store.balanceOf[account] = accountBalance - amount;
        }
        store.totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}