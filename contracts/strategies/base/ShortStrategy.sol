// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal virtual view returns (uint256[] memory reserves, address payee);

    function getReserves(address cfmm) internal virtual view returns(uint256[] memory);

    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum) public view virtual override returns(uint256) {
        uint256 lastCFMMInvariant = calcInvariant(cfmm, getReserves(cfmm));
        uint256 lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
        uint256 lastFeeIndex = calcFeeIndex(calcCFMMFeeIndex(lastCFMMInvariant, lastCFMMTotalSupply, prevCFMMInvariant, prevCFMMTotalSupply), calcBorrowRate(lpBalance, lpBorrowed), lastBlockNum);
        return lpBalance + calcLPTokenBorrowedPlusInterest(accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex), lastCFMMTotalSupply, lastCFMMInvariant);
    }

    //********* Short Gamma Functions *********//
    function _depositNoPull(address to) external virtual override lock returns(uint256 shares) {
        shares = _depositAssetsNoPull(to);
    }

    function _depositAssetsNoPull(address to) internal virtual returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 assets = GammaSwapLibrary.balanceOf(store.cfmm, address(this)) - store.LP_TOKEN_BALANCE;

        updateIndex(store);

        shares = _convertToShares(store, assets);
        if(shares == 0) {
            revert ZeroShares();
        }
        _depositAssets(store, msg.sender, to, assets, shares);
    }

    function _withdrawNoPull(address to) external virtual override lock returns(uint256 assets) {
        (,assets) = _withdrawAssetsNoPull(to, false);
    }

    function preDepositToCFMM(GammaPoolStorage.Store storage store, uint256[] memory amounts, address to, bytes memory data) internal virtual {
        address[] storage tokens = store.tokens;
        uint256[] memory balances = new uint256[](tokens.length);
        for(uint256 i = 0; i < tokens.length; i++) {
            balances[i] = GammaSwapLibrary.balanceOf(tokens[i], to);
        }
        ISendTokensCallback(msg.sender).sendTokensCallback(tokens, amounts, to, data); // TODO: Risky. Should set sender to PosMgr
        for(uint256 i = 0; i < tokens.length; i++) {
            if(amounts[i] > 0) {
                if(balances[i] + amounts[i] != GammaSwapLibrary.balanceOf(tokens[i], to)) {
                    revert WrongTokenBalance(tokens[i]);
                }
            }
        }
    }

    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override lock returns(uint256[] memory reserves, uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        address payee;
        (reserves, payee) = calcDepositAmounts(store, amountsDesired, amountsMin);

        preDepositToCFMM(store, reserves, payee, data);

        depositToCFMM(store.cfmm, reserves, address(this));

        shares = _depositAssetsNoPull(to);
    }

    function _withdrawReserves(address to) external virtual override lock returns(uint256[] memory reserves, uint256 assets) {//TODO: Should probably change the name of this function (maybe withdrawReserves)
        (reserves, assets) = _withdrawAssetsNoPull(to, true);
    }

    function _withdrawAssetsNoPull(address to, bool askForReserves) internal virtual returns(uint256[] memory reserves, uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 shares = store.balanceOf[address(this)];

        updateIndex(store);

        assets = _convertToAssets(store, shares);
        if(assets == 0) {
            revert ZeroShares();
        }

        if(assets > store.LP_TOKEN_BALANCE) {//TODO: assets <= store.LP_TOKEN_BALANCE must be true. This is what maxRedeem is
            revert ExcessiveWithdrawal();
        }
        reserves = _withdrawAssets(store, address(this), to, address(this), assets, shares, askForReserves);
    }

    //*************ERC-4626 functions************//

    function _depositAssets(
        GammaPoolStorage.Store storage store,
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        _mint(store, receiver, shares);
        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit Deposit(caller, receiver, assets, shares);
        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);

        afterDeposit(store, assets, shares);
    }

    function _withdrawAssets(
        GammaPoolStorage.Store storage store,
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        bool askForReserves
    ) internal virtual returns(uint256[] memory reserves){
        if (caller != owner) {
            _spendAllowance(store, owner, caller, shares);
        }

        beforeWithdraw(store, assets, shares);

        _burn(store, owner, shares);
        if(askForReserves) {
            reserves = withdrawFromCFMM(store.cfmm, receiver, assets);
        } else {
            GammaSwapLibrary.safeTransfer(store.cfmm, receiver, assets);
        }
        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));

        emit Withdraw(caller, receiver, owner, assets, shares);
        emit PoolUpdated(store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LAST_BLOCK_NUMBER, store.accFeeIndex,
            store.lastFeeIndex, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_INVARIANT, store.BORROWED_INVARIANT);
    }

    function _spendAllowance(
        GammaPoolStorage.Store storage store,
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 allowed = store.allowance[owner][spender]; // Saves gas for limited approvals.
        if (allowed != type(uint256).max) {
            if(allowed < amount) {
                revert ExcessiveSpend();
            }
            unchecked {
                store.allowance[owner][spender] = allowed - amount;
            }
        }
    }

    //ACCOUNTING LOGIC

    function _convertToShares(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = store.LP_TOKEN_TOTAL;
        return supply == 0 || _totalAssets == 0 ? assets : (assets * supply) / _totalAssets;
    }

    function _convertToAssets(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply;
        return supply == 0 ? shares : (shares * store.LP_TOKEN_TOTAL) / supply;
    }

    //INTERNAL HOOKS LOGIC

    function beforeWithdraw(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}
}
