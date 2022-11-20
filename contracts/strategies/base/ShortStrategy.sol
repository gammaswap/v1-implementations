// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@gammaswap/v1-core/contracts/interfaces/strategies/base/IShortStrategy.sol";
import "@gammaswap/v1-periphery/contracts/interfaces/ISendTokensCallback.sol";
import "./BaseStrategy.sol";

abstract contract ShortStrategy is IShortStrategy, BaseStrategy {

    error ZeroShares();
    error ZeroAssets();
    error ExcessiveWithdrawal();
    error WrongTokenBalance(address);
    error ExcessiveSpend();

    //ShortGamma
    function calcDepositAmounts(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal virtual view returns (uint256[] memory reserves, address payee);

    function getReserves(address cfmm) internal virtual view returns(uint256[] memory);

    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum) public view virtual override returns(uint256) {
        uint256 lastCFMMInvariant = calcInvariant(cfmm, getReserves(cfmm));
        uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(IERC20(cfmm));
        uint256 lpInvariant = calcLPInvariant(lpBalance, prevCFMMInvariant, prevCFMMTotalSupply);
        uint256 lastFeeIndex = calcFeeIndex(calcCFMMFeeIndex(borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply, prevCFMMInvariant, prevCFMMTotalSupply), calcBorrowRate(lpInvariant, borrowedInvariant), lastBlockNum);
        return lpBalance + calcLPTokenBorrowedPlusInterest(accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex), lastCFMMTotalSupply, lastCFMMInvariant);
    }

    //********* Short Gamma Functions *********//
    function _depositNoPull(address to) external virtual override lock returns(uint256 shares) {
        shares = _depositAssetsNoPull(to);
    }

    function _depositAssetsNoPull(address to) internal virtual returns(uint256 shares) {
        uint256 assets = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this)) - s.LP_TOKEN_BALANCE;

        updateIndex();

        shares = _convertToShares(assets);
        if(shares == 0) {
            revert ZeroShares();
        }
        _depositAssets(msg.sender, to, assets, shares);
    }

    function _withdrawNoPull(address to) external virtual override lock returns(uint256 assets) {
        (,assets) = _withdrawAssetsNoPull(to, false);
    }

    function preDepositToCFMM(uint256[] memory amounts, address to, bytes memory data) internal virtual {
        address[] storage tokens = s.tokens;
        uint256[] memory balances = new uint256[](tokens.length);
        for(uint256 i = 0; i < tokens.length; i++) {
            balances[i] = GammaSwapLibrary.balanceOf(IERC20(tokens[i]), to);
        }
        ISendTokensCallback(msg.sender).sendTokensCallback(tokens, amounts, to, data); // TODO: Risky. Should set sender to PosMgr
        for(uint256 i = 0; i < tokens.length; i++) {
            if(amounts[i] > 0) {
                if(balances[i] + amounts[i] != GammaSwapLibrary.balanceOf(IERC20(tokens[i]), to)) {
                    revert WrongTokenBalance(tokens[i]);
                }
            }
        }
    }

    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override lock returns(uint256[] memory reserves, uint256 shares) {
        address payee;
        (reserves, payee) = calcDepositAmounts(amountsDesired, amountsMin);

        preDepositToCFMM(reserves, payee, data);

        depositToCFMM(s.cfmm, reserves, address(this));

        shares = _depositAssetsNoPull(to);
    }

    function _withdrawReserves(address to) external virtual override lock returns(uint256[] memory reserves, uint256 assets) {
        (reserves, assets) = _withdrawAssetsNoPull(to, true);
    }

    function _withdrawAssetsNoPull(address to, bool askForReserves) internal virtual returns(uint256[] memory reserves, uint256 assets) {
        uint256 shares = s.balanceOf[address(this)];

        updateIndex();

        assets = _convertToAssets(shares);
        if(assets == 0) {
            revert ZeroAssets();
        }

        if(assets > s.LP_TOKEN_BALANCE) {
            revert ExcessiveWithdrawal();
        }
        reserves = _withdrawAssets(address(this), to, address(this), assets, shares, askForReserves);
    }

    //*************ERC-4626 functions************//

    function _depositAssets(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        _mint(receiver, shares);
        s.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));

        emit Deposit(caller, receiver, assets, shares);
        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);

        afterDeposit(assets, shares);
    }

    function _withdrawAssets(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        bool askForReserves
    ) internal virtual returns(uint256[] memory reserves){
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);
        if(askForReserves) {
            reserves = withdrawFromCFMM(s.cfmm, receiver, assets);
        } else {
            GammaSwapLibrary.safeTransfer(IERC20(s.cfmm), receiver, assets);
        }
        s.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));

        emit Withdraw(caller, receiver, owner, assets, shares);
        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.lastFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 allowed = s.allowance[owner][spender]; // Saves gas for limited approvals.
        if (allowed != type(uint256).max) {
            if(allowed < amount) {
                revert ExcessiveSpend();
            }
            unchecked {
                s.allowance[owner][spender] = allowed - amount;
            }
        }
    }

    //ACCOUNTING LOGIC

    function _convertToShares(uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = s.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST;//s.LP_TOKEN_TOTAL;
        return supply == 0 || _totalAssets == 0 ? assets : (assets * supply) / _totalAssets;
    }

    function _convertToAssets(uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = s.totalSupply;
        //return supply == 0 ? shares : (shares * s.LP_TOKEN_TOTAL) / supply;
        return supply == 0 ? shares : (shares * (s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST)) / supply;
    }

    //INTERNAL HOOKS LOGIC

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}
