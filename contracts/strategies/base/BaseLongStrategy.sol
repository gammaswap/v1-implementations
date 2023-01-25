// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./BaseStrategy.sol";

/// @title Base Long Strategy implementation contract
/// @author Daniel D. Alcarraz
/// @notice Common functions used by all strategy implementations that need access to loans
/// @dev This contract inherits from BaseStrategy and should normally be inherited by LongStrategy and LiquidationStrategy
abstract contract BaseLongStrategy is BaseStrategy {

    error Forbidden();
    error Margin();

    /// @dev Perform necessary transaction before repaying liquidity debt
    /// @param loan - liquidity loan that will be repaid
    /// @param amounts - collateral amounts that will be used to repay liquidity loan
    function beforeRepay(LibStorage.Loan storage loan, uint256[] memory amounts) internal virtual;

    /// @dev Calculate token amounts the liquidity invariant amount converts to in the CFMM
    /// @param liquidity - liquidity invariant units from CFMM
    /// @return amounts - reserve token amounts in CFMM that liquidity invariant converted to
    function calcTokensToRepay(uint256 liquidity) internal virtual view returns(uint256[] memory amounts);

    /// @dev Perform necessary transaction before repaying swapping tokens
    /// @param loan - liquidity loan whose collateral will be swapped
    /// @param deltas - collateral amounts that will be swapped (> 0 buy, < 0 sell, 0 ignore)
    /// @return outAmts - collateral amounts that will be sent out of GammaPool (sold)
    /// @return inAmts - collateral amounts that will be received in GammaPool (bought)
    function beforeSwapTokens(LibStorage.Loan storage loan, int256[] calldata deltas) internal virtual returns(uint256[] memory outAmts, uint256[] memory inAmts);

    /// @dev Calculate tokens liquidity invariant amount converts to in CFMM
    /// @param loan - liquidity loan whose collateral will be traded
    /// @param outAmts - expected amounts to send to CFMM (sold),
    /// @param inAmts - expected amounts to receive from CFMM (bought)
    function swapTokens(LibStorage.Loan storage loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual;

    /// @return origFee - origination fee charged to every new loan that is issued
    function originationFee() internal virtual view returns(uint16);

    /// @return LTV_THRESHOLD - max ltv ratio acceptable before a loan is eligible for liquidation
    function ltvThreshold() internal virtual view returns(uint16);

    /// @dev Get `loan` from `tokenId` and authenticate requester has permission to get loan
    /// @param tokenId - liquidity loan whose collateral will be traded
    /// @return loan - origination fee charged to every new loan that is issued
    function _getLoan(uint256 tokenId) internal virtual view returns(LibStorage.Loan storage loan) {
        loan = s.loans[tokenId]; // read loan
        // revert if keccak256 hash of msg.sender, GammaPool address, and loan counter at time of loan creation is not tokenId
        if(tokenId != uint256(keccak256(abi.encode(msg.sender, address(this), loan.id)))) {
            revert Forbidden();
        }
    }

    /// @dev Check if loan is undercollateralized
    /// @param collateral - liquidity invariant collateral
    /// @param liquidity - liquidity invariant debt
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual view;

    /// @dev Check if loan is over collateralized
    /// @param collateral - liquidity invariant collateral
    /// @param liquidity - liquidity invariant debt
    /// @param limit - loan to value ratio limit in tenths of a percent (e.g. 800 => 80%)
    /// @return bool - true if loan is over collateralized, false otherwise
    function hasMargin(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual pure returns(bool) {
        return collateral * limit / 1000 >= liquidity;
    }

    function sendTokens(LibStorage.Loan storage _loan, address to, uint256[] memory amounts) internal virtual {
        address[] memory tokens = s.tokens;
        for (uint256 i; i < tokens.length;) {
            if(amounts[i] > 0) {
                sendToken(IERC20(tokens[i]), to, amounts[i], s.TOKEN_BALANCE[i], _loan.tokensHeld[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    function repayTokens(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual returns(uint256) {
        beforeRepay(_loan, amounts); // in balancer we do nothing here, in uni we send tokens here, definitely not going over since we check here that we have the collateral to send.
        return depositToCFMM(s.cfmm, amounts, address(this));//in balancer pulls tokens here and mints, in Uni it just mints)
    }

    function updateLoan(LibStorage.Loan storage _loan) internal virtual returns(uint256) {
        (uint256 accFeeIndex,,) = updateIndex();
        return updateLoanLiquidity(_loan, accFeeIndex);
    }

    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual returns(uint256 liquidity) {
        uint256 _rateIndex = _loan.rateIndex;
        liquidity = _rateIndex == 0 ? 0 : (_loan.liquidity * accFeeIndex) / _rateIndex;
        _loan.liquidity = uint128(liquidity);
        _loan.rateIndex = uint96(accFeeIndex);
    }

    function openLoan(LibStorage.Loan storage _loan, uint256 lpTokens) internal virtual returns(uint256 liquidity){
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 liquidityBorrowedExFee = calcLPInvariant(lpTokens, lastCFMMInvariant, lastCFMMTotalSupply);
        uint256 lpTokensPlusOrigFee = lpTokens + lpTokens * originationFee() / 10000;
        uint256 liquidityBorrowed = calcLPInvariant(lpTokensPlusOrigFee, lastCFMMInvariant, lastCFMMTotalSupply);// The liquidity it represented at that time
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + liquidityBorrowed;
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED + lpTokens;

        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));// this can be greater than expected (accrues to LPs), but can't be less (it's withdrawal of LP_TOKENS)
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        lastCFMMInvariant = lastCFMMInvariant - liquidityBorrowedExFee;
        lastCFMMTotalSupply = lastCFMMTotalSupply - lpTokens;
        uint256 lpInvariant = calcLPInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);
        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokensPlusOrigFee;

        liquidity = _loan.liquidity + liquidityBorrowed;
        _loan.initLiquidity = _loan.initLiquidity + uint128(liquidityBorrowed);
        _loan.lpTokens = _loan.lpTokens + lpTokens;
        _loan.liquidity = uint128(liquidity);
    }

    function payLoan(LibStorage.Loan storage _loan, uint256 liquidity, uint256 loanLiquidity) internal virtual returns(uint256 remainingLiquidity) {
        (uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 paidLiquidity, uint256 newLPBalance, uint256 lpTokenChange) = getLpTokenBalance();
        liquidity = paidLiquidity < liquidity ? paidLiquidity : liquidity; // take the lowest, if actually paid less liquidity than expected. Only way is there was a transfer fee.
        // if more liquidity than stated was actually paid, that goes to liquidity providers
        uint256 lpTokenPrincipal;
        (lpTokenPrincipal, remainingLiquidity) = payLoanLiquidity(liquidity, loanLiquidity, _loan);

        payPoolDebt(liquidity, lpTokenPrincipal, lastCFMMInvariant, lastCFMMTotalSupply, newLPBalance, lpTokenChange);
    }

    function getLpTokenBalance() internal view virtual returns(uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 paidLiquidity, uint256 newLPBalance, uint256 lpTokenChange) {
        newLPBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));// so lp balance is supposed to be greater than before, no matter what since tokens were deposited into the CFMM
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE;
        if(newLPBalance <= lpTokenBalance) {// the change will always be positive, might be greater than expected, which means you paid more. If it's less it will be a small difference because of a fee
            revert NotEnoughLPDeposit();
        }
        lpTokenChange = newLPBalance - lpTokenBalance;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        paidLiquidity = calcLPInvariant(lpTokenChange, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    function payPoolDebt(uint256 liquidity, uint256 lpTokenPrincipal, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 newLPBalance, uint256 lpTokenPaid) internal virtual {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        uint256 lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        uint256 _lpTokenPaid = calcLPTokenBorrowedPlusInterest(liquidity, lpTokenBorrowedPlusInterest, borrowedInvariant);// what borrower actually paid
        lastCFMMInvariant = lastCFMMInvariant + calcLPTokenBorrowedPlusInterest(lpTokenPaid, lastCFMMInvariant, lastCFMMTotalSupply);// what was actually received in LP tokens
        lastCFMMTotalSupply = lastCFMMTotalSupply + lpTokenPaid;//how much total supply went up by

        borrowedInvariant = borrowedInvariant - liquidity; // won't overflow
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);

        s.LP_TOKEN_BALANCE = newLPBalance;// this can be greater than expected (accrues to LPs), or less if there's a token transfer fee
        uint256 lpInvariant = calcLPInvariant(newLPBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);
        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokenBorrowedPlusInterest - _lpTokenPaid; // won't overflow

        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED - lpTokenPrincipal;
    }

    function payLoanLiquidity(uint256 liquidity, uint256 loanLiquidity, LibStorage.Loan storage _loan) internal virtual
        returns(uint256 lpTokenPrincipal, uint256 remainingLiquidity) {
        uint256 loanLpTokens = _loan.lpTokens;
        uint256 loanInitLiquidity = _loan.initLiquidity;
        lpTokenPrincipal = calcLPTokenBorrowedPlusInterest(liquidity, loanLpTokens, loanLiquidity);
        _loan.initLiquidity = uint128(loanInitLiquidity - calcLPTokenBorrowedPlusInterest(liquidity, loanInitLiquidity, loanLiquidity));
        _loan.lpTokens = loanLpTokens - lpTokenPrincipal;
        remainingLiquidity = loanLiquidity - liquidity;
        _loan.liquidity = uint128(remainingLiquidity);
        if(remainingLiquidity == 0) {
            _loan.rateIndex = 0;
        }
    }

    function sendToken(IERC20 token, address to, uint256 amount, uint256 balance, uint256 collateral) internal {
        if(amount > balance){
            revert NotEnoughBalance();
        }
        if(amount > collateral){
            revert NotEnoughCollateral();
        }
        GammaSwapLibrary.safeTransfer(token, to, amount);
    }

    function updateCollateral(LibStorage.Loan storage _loan) internal returns(uint128[] memory tokensHeld){
        address[] memory tokens = s.tokens;
        uint128[] memory tokenBalance = s.TOKEN_BALANCE;
        tokensHeld = _loan.tokensHeld;
        for (uint256 i; i < tokens.length;) {
            uint256 currentBalance = GammaSwapLibrary.balanceOf(IERC20(tokens[i]), address(this));
            if(currentBalance > tokenBalance[i]) {
                uint128 balanceChange = uint128(currentBalance - tokenBalance[i]);
                tokensHeld[i] = tokensHeld[i] + balanceChange;
                tokenBalance[i] = tokenBalance[i] + balanceChange;
            } else if(currentBalance < tokenBalance[i]) {
                uint128 balanceChange = uint128(tokenBalance[i] - currentBalance);
                if(balanceChange > tokenBalance[i]){
                    revert NotEnoughBalance();
                }
                if(balanceChange > tokensHeld[i]){
                    revert NotEnoughCollateral();
                }
                unchecked {
                    tokensHeld[i] = tokensHeld[i] - balanceChange;
                    tokenBalance[i] = tokenBalance[i] - balanceChange;
                }
            }
            unchecked {
                ++i;
            }
        }
        _loan.tokensHeld = tokensHeld;
        s.TOKEN_BALANCE = tokenBalance;
    }
}
