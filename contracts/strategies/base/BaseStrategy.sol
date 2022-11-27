// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/GammaPoolFactory.sol";
import "@gammaswap/v1-core/contracts/storage/AppStorage.sol";

import "../../libraries/GammaSwapLibrary.sol";
import "../../interfaces/rates/AbstractRateModel.sol";

abstract contract BaseStrategy is AppStorage, AbstractRateModel {
    error ZeroAmount();
    error ZeroAddress();
    error ExcessiveBurn();
    error NotEnoughLPDeposit();
    error NotEnoughBalance();
    error NotEnoughCollateral();

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function updateReserves() internal virtual;

    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual view returns(uint256);

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual returns(uint256 liquidity);

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual returns(uint256[] memory amounts);

    function calcCFMMFeeIndex(uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply) internal virtual view returns(uint256) {
        if(lastCFMMInvariant > 0 && lastCFMMTotalSupply > 0 && prevCFMMInvariant > 0 && prevCFMMTotalSupply > 0) {
            uint256 prevInvariant = borrowedInvariant > prevCFMMInvariant ? borrowedInvariant : prevCFMMInvariant; // deleverage CFMM Yield
            uint256 denominator = (prevInvariant * lastCFMMTotalSupply) / 10**18;
            return ((lastCFMMInvariant * prevCFMMTotalSupply + lastCFMMTotalSupply * (prevInvariant - prevCFMMInvariant)) / denominator);
        }
        return 10**18;
    }

    function calcFeeIndex(uint256 lastCFMMFeeIndex, uint256 borrowRate, uint256 lastBlockNum) internal virtual view returns(uint256) {
        uint256 blockDiff = block.number - lastBlockNum;
        uint256 adjBorrowRate = (blockDiff * borrowRate) / 2252571;//2252571 year block count
        return lastCFMMFeeIndex + adjBorrowRate;
    }

    function updateCFMMIndex() internal virtual {
        updateReserves();
        uint256 lastCFMMInvariant = calcInvariant(s.cfmm, s.CFMM_RESERVES);
        uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(IERC20(s.cfmm));
        uint256 lastCFMMFeeIndex = calcCFMMFeeIndex(s.BORROWED_INVARIANT, lastCFMMInvariant, lastCFMMTotalSupply, s.lastCFMMInvariant, s.lastCFMMTotalSupply);
        s.lastCFMMFeeIndex = uint80(lastCFMMFeeIndex);
        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    function updateFeeIndex() internal virtual {
        s.lastFeeIndex = uint80(calcFeeIndex(s.lastCFMMFeeIndex, calcBorrowRate(s.LP_INVARIANT, s.BORROWED_INVARIANT), s.LAST_BLOCK_NUMBER));
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

    function updateStore() internal virtual returns(uint256 lastFeeIndex, uint256 accFeeIndex) {
        lastFeeIndex = s.lastFeeIndex;
        //lastFeeIndex = uint80(calcFeeIndex(s.lastCFMMFeeIndex, calcBorrowRate(s.LP_INVARIANT, s.BORROWED_INVARIANT), s.LAST_BLOCK_NUMBER));
        s.BORROWED_INVARIANT = uint128(accrueBorrowedInvariant(s.BORROWED_INVARIANT, lastFeeIndex));

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = calcLPTokenBorrowedPlusInterest(s.BORROWED_INVARIANT, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        s.LP_INVARIANT = uint128(calcLPInvariant(s.LP_TOKEN_BALANCE, s.lastCFMMInvariant, s.lastCFMMTotalSupply));

        accFeeIndex = (s.accFeeIndex * lastFeeIndex) / 10**18;
        s.accFeeIndex = uint96(accFeeIndex);
        s.LAST_BLOCK_NUMBER = uint48(block.number);
    }

    function updateIndex() internal virtual returns(uint256 accFeeIndex) {

        updateCFMMIndex();
        updateFeeIndex();
        uint256 lastFeeIndex;
        (lastFeeIndex, accFeeIndex) = updateStore();

        if(s.BORROWED_INVARIANT >= 0) {
            // mintToDevs(lastFeeIndex);
        }
    }

    function mintToDevs(uint256 lastFeeIndex) internal {
        (address feeTo, uint256 devFee) = IGammaPoolFactory(s.factory).feeInfo();
        if(feeTo != address(0) && devFee > 0) {
            //Formula:
            //        accumulatedGrowth: (1 - [borrowedInvariant/(borrowedInvariant*index)])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
            //        accumulatedGrowth: (1 - [1/index])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
            //        sharesToIssue: totalGammaTokenSupply*accGrowth/(1-accGrowth)
            uint256 totalInvariantInCFMM = ((s.LP_TOKEN_BALANCE * s.lastCFMMInvariant) / s.lastCFMMTotalSupply);//How much Invariant does this contract have from LP_TOKEN_BALANCE
            //uint256 factor = ((s.lastFeeIndex - (10**18)) * devFee) / s.lastFeeIndex;//Percentage of the current growth that we will give to devs
            uint256 factor = ((lastFeeIndex - (10**18)) * devFee) / lastFeeIndex;//Percentage of the current growth that we will give to devs
            uint256 accGrowth = (factor * s.BORROWED_INVARIANT) / (s.BORROWED_INVARIANT + totalInvariantInCFMM);
            //_mint(feeTo, (s.totalSupply * accGrowth) / ((10**18) - accGrowth));
            _mint(feeTo, (s.totalSupply * accGrowth) / ((10**18) - accGrowth));
        }
    }

    function updateLoan(LibStorage.Loan storage _loan) internal virtual returns(uint256){
        uint256 accFeeIndex = updateIndex();
        return updateLoanLiquidity(_loan, accFeeIndex);
    }

    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual returns(uint256 liquidity){
        liquidity = (_loan.liquidity * accFeeIndex) / _loan.rateIndex;
        _loan.liquidity = uint128(liquidity);
        _loan.rateIndex = uint96(accFeeIndex);
    }

    function _mint(address account, uint256 amount) internal virtual {
        if(amount == 0) {
            revert ZeroAmount();
        }
        s.totalSupply += amount;
        s.balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        if(account == address(0)) {
            revert ZeroAddress();
        }
        uint256 accountBalance = s.balanceOf[account];
        if(amount > accountBalance) {
            revert ExcessiveBurn();
        }
        unchecked {
            s.balanceOf[account] = accountBalance - amount;
        }
        s.totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}