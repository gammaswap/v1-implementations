// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@gammaswap/v1-core/contracts/libraries/storage/GammaPoolStorage.sol";

import "../../libraries/GammaSwapLibrary.sol";
import "../../interfaces/rates/AbstractRateModel.sol";

abstract contract BaseStrategy is AbstractRateModel {
    error ZeroAmount();
    error ZeroAddress();
    error ExcessiveBurn();

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);
    event Transfer(address indexed from, address indexed to, uint256 value);

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    function updateReserves(GammaPoolStorage.Store storage store) internal virtual;

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual view returns(uint256);

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual returns(uint256 liquidity);

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual returns(uint256[] memory amounts);

    function updateTWAP(GammaPoolStorage.Store storage store) internal virtual {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - store.lastBlockTimestamp;
        uint32 secondsInADay = 86400;
        if (timeElapsed > 0) {
            if (timeElapsed >= secondsInADay) { // reset
                store.cumulativeTime = 0;
                store.cumulativeYield = 0;
            }
            if (store.cumulativeTime < secondsInADay) {
                store.cumulativeTime += timeElapsed;
                store.cumulativeYield += timeElapsed * store.lastFeeIndex;
                store.yieldTWAP = store.cumulativeYield / store.cumulativeTime;
            } else {
                store.yieldTWAP = (store.yieldTWAP * (secondsInADay - timeElapsed) + store.lastFeeIndex * timeElapsed) / secondsInADay;
            }
        }
        store.lastBlockTimestamp = blockTimestamp;
    }

    function calcCFMMFeeIndex(uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply) internal virtual view returns(uint256) {
        uint256 ONE = 10**18;
        if(lastCFMMInvariant > 0 && lastCFMMTotalSupply > 0 && prevCFMMInvariant > 0 && prevCFMMTotalSupply > 0) {
            uint256 denominator = (prevCFMMInvariant * lastCFMMTotalSupply) / ONE;
            return (lastCFMMInvariant * prevCFMMTotalSupply) / denominator;
        }
        return ONE;
    }

    function calcFeeIndex(uint256 lastCFMMFeeIndex, uint256 borrowRate, uint256 lastBlockNum) internal virtual view returns(uint256) {
        uint256 blockDiff = block.number - lastBlockNum;
        uint256 adjBorrowRate = (blockDiff * borrowRate) / 2252571;//2252571 year block count
        return lastCFMMFeeIndex + adjBorrowRate;
    }

    function updateCFMMIndex(GammaPoolStorage.Store storage store) internal virtual {
        updateReserves(store);
        uint256 lastCFMMInvariant = calcInvariant(store.cfmm, store.CFMM_RESERVES);
        uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(store.cfmm);
        store.lastCFMMFeeIndex = calcCFMMFeeIndex(lastCFMMInvariant, lastCFMMTotalSupply, store.lastCFMMInvariant, store.lastCFMMTotalSupply);
        store.lastCFMMInvariant = lastCFMMInvariant;
        store.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    function updateFeeIndex(GammaPoolStorage.Store storage store) internal virtual {
        store.borrowRate = calcBorrowRate(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED);
        store.lastFeeIndex = calcFeeIndex(store.lastCFMMFeeIndex, store.borrowRate, store.LAST_BLOCK_NUMBER);
    }

    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual pure returns(uint256) {
        return  borrowedInvariant * lastFeeIndex / (10**18);
    }

    function calcLPTokenBorrowedPlusInterest(uint256 borrowedInvariant, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) internal virtual pure returns(uint256) {
        return lastCFMMInvariant == 0 ? 0 : (borrowedInvariant * lastCFMMTotalSupply) / lastCFMMInvariant;
    }

    function calcLPInvariant(uint256 lpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual pure returns(uint256) {
        return lastCFMMTotalSupply == 0 ? 0 : (lpTokenBalance * lastCFMMInvariant) / lastCFMMTotalSupply;
    }

    function updateStore(GammaPoolStorage.Store storage store) internal virtual {
        store.BORROWED_INVARIANT = accrueBorrowedInvariant(store.BORROWED_INVARIANT, store.lastFeeIndex);

        store.LP_TOKEN_BORROWED_PLUS_INTEREST = calcLPTokenBorrowedPlusInterest(store.BORROWED_INVARIANT, store.lastCFMMTotalSupply, store.lastCFMMInvariant);
        store.LP_INVARIANT = calcLPInvariant(store.LP_TOKEN_BALANCE, store.lastCFMMInvariant, store.lastCFMMTotalSupply);
        store.LP_TOKEN_TOTAL = store.LP_TOKEN_BALANCE + store.LP_TOKEN_BORROWED_PLUS_INTEREST;
        store.TOTAL_INVARIANT = store.LP_INVARIANT + store.BORROWED_INVARIANT;

        store.accFeeIndex = (store.accFeeIndex * store.lastFeeIndex) / store.ONE;
        store.LAST_BLOCK_NUMBER = block.number;
    }

    function updateIndex(GammaPoolStorage.Store storage store) internal virtual {

        updateCFMMIndex(store);
        updateFeeIndex(store);
        // updateTWAP(store);
        updateStore(store);

        if(store.BORROWED_INVARIANT >= 0) {
            // mintToDevs(store);
        }
    }

    function mintToDevs(GammaPoolStorage.Store storage store) internal {
        (address feeTo, uint256 devFee) = IGammaPoolFactory(store.factory).feeInfo();
        if(feeTo != address(0) && devFee > 0) {
            //Formula:
            //        accumulatedGrowth: (1 - [borrowedInvariant/(borrowedInvariant*index)])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
            //        accumulatedGrowth: (1 - [1/index])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
            //        sharesToIssue: totalGammaTokenSupply*accGrowth/(1-accGrowth)
            uint256 totalInvariantInCFMM = ((store.LP_TOKEN_BALANCE * store.lastCFMMInvariant) / store.lastCFMMTotalSupply);//How much Invariant does this contract have from LP_TOKEN_BALANCE
            //uint256 factor = ((store.lastFeeIndex - (10**18)) * devFee) / store.lastFeeIndex;//Percentage of the current growth that we will give to devs
            uint256 factor = ((store.lastFeeIndex - store.ONE) * devFee) / store.lastFeeIndex;//Percentage of the current growth that we will give to devs
            uint256 accGrowth = (factor * store.BORROWED_INVARIANT) / (store.BORROWED_INVARIANT + totalInvariantInCFMM);
            //_mint(store, feeTo, (store.totalSupply * accGrowth) / ((10**18) - accGrowth));
            _mint(store, feeTo, (store.totalSupply * accGrowth) / (store.ONE - accGrowth));
        }
    }

    function updateLoan(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan) internal virtual {
        updateIndex(store);
        updateLoanLiquidity(_loan, store.accFeeIndex);
    }

    function updateLoanLiquidity(GammaPoolStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual {
        _loan.liquidity = (_loan.liquidity * accFeeIndex) / _loan.rateIndex;
        _loan.rateIndex = accFeeIndex;
    }

    function _mint(GammaPoolStorage.Store storage store, address account, uint256 amount) internal virtual {
        if(amount == 0) {
            revert ZeroAmount();
        }
        store.totalSupply += amount;
        store.balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(GammaPoolStorage.Store storage store, address account, uint256 amount) internal virtual {
        if(account == address(0)) {
            revert ZeroAddress();
        }
        uint256 accountBalance = store.balanceOf[account];
        if(amount > accountBalance) {
            revert ExcessiveBurn();
        }
        unchecked {
            store.balanceOf[account] = accountBalance - amount;
        }
        store.totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}