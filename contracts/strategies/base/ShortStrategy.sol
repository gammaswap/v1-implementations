// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@gammaswap/v1-core/contracts/interfaces/strategies/base/IShortStrategy.sol";
import "./BaseStrategy.sol";
import "../../interfaces/ISendTokensCallback.sol";

abstract contract ShortStrategy is IShortStrategy, BaseStrategy {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    //ShortGamma
    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal virtual returns (uint256[] memory reserves, address payee);

    function getReserves(address cfmm) internal virtual view returns(uint256[] memory);

    function getBorrowRate(uint256 lpBalance, uint256 lpBorrowed) public virtual override view returns(uint256) {
        return calcBorrowRate(lpBalance, lpBorrowed);
    }

    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum) public view virtual override returns(uint256) {
        (uint256 lastFeeIndex,, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) = calcFeeIndex(cfmm, getBorrowRate(lpBalance, lpBorrowed), prevCFMMInvariant, prevCFMMTotalSupply, lastBlackNum);
        borrowedInvariant = borrowedInvariant * lastFeeIndex / (10**18);
        return lpBalance + (borrowedInvariant * lastCFMMTotalSupply) / lastCFMMInvariant;
    }

    function calcFeeIndex(address cfmm, uint256 borrowRate, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum)
        public virtual override view returns(uint256 lastFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        uint256 ONE = 10**18;
        lastCFMMFeeIndex = ONE;
        {
            lastCFMMInvariant = calcInvariant(cfmm, getReserves(cfmm));
            lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
        }

        if(lastCFMMTotalSupply > 0) {
            uint256 denominator = (prevCFMMInvariant * lastCFMMTotalSupply) / ONE;
            lastCFMMFeeIndex = (lastCFMMInvariant * prevCFMMTotalSupply) / denominator;
        }

        {
            uint256 blockDiff = block.number - lastBlackNum;
            uint256 adjBorrowRate = (blockDiff * borrowRate) / 2252571;//2252571 year block count
            lastFeeIndex = lastCFMMFeeIndex + adjBorrowRate;
        }
    }

    function calcBorrowedLPTokensPlusInterest(uint256 borrowedInvariant, uint256 lastFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual override pure returns(uint256) {
        borrowedInvariant = borrowedInvariant * lastFeeIndex / (10**18);
        return (borrowedInvariant * lastCFMMTotalSupply) / lastCFMMInvariant;
    }



    //********* Short Gamma Functions *********//
    function _depositNoPull(address to) public virtual override lock returns(uint256 shares) {//TODO: Should probably change the name of this function (addReserves)
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 assets = GammaSwapLibrary.balanceOf(store.cfmm, address(this)) - store.LP_TOKEN_BALANCE;
        require(assets > 0, '0 dep');

        updateIndex(store);

        require((shares = _previewDeposit(store, assets)) != 0, "ZERO_SHARES");

        _mint(store, to, shares);
        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));
        //emit Mint(msg.sender, amountA, amountB);
    }

    function _withdrawNoPull(address to) public virtual override lock returns(uint256 assets) {//TODO: Should probably change the name of this function (addReserves)
        //get the liquidity tokens
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 shares = store.balanceOf[address(this)];
        require(shares > 0, '0 shares');

        updateIndex(store);

        require((assets = _previewRedeem(store, shares)) <= store.LP_TOKEN_BALANCE, '> liq');

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call strategy and ask strategy to use callback to transfer to CFMM then strategy calls burn
        //Bal/Crv: U -> GP -> Strategy -> CFMM -> Strategy -> U
        //                    just call strategy and ask strategy to use callback to transfer to Strategy then to CFMM
        //                    Since CFMM has to pull from strategy, strategy must always check it has enough approval
        address cfmm = store.cfmm;
        GammaSwapLibrary.safeTransfer(cfmm, to, assets);
        _burn(store, address(this), shares);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));
        //emit Burn(msg.sender, _amount0, _amount1, uniLiquidity, to);
    }

    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override lock returns(uint256[] memory reserves, uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        address payee;
        (reserves, payee) = calcDepositAmounts(store, amountsDesired, amountsMin);

        address[] storage tokens = store.tokens;
        uint256[] memory balances = new uint256[](tokens.length);
        for(uint256 i = 0; i < tokens.length; i++) {
            balances[i] = GammaSwapLibrary.balanceOf(tokens[i], address(this));
        }
        ISendTokensCallback(msg.sender).sendTokensCallback(tokens, reserves, payee, data);
        for(uint256 i = 0; i < tokens.length; i++) {
            if(reserves[i] > 0) require(balances[i] + reserves[i] == GammaSwapLibrary.balanceOf(tokens[i], address(this)), "WL");
        }

        depositToCFMM(store.cfmm, reserves, address(this));

        shares = _depositNoPull(to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function _withdrawReserves(address to) public virtual override lock returns(uint256[] memory reserves, uint256 assets) {//TODO: Should probably change the name of this function (maybe withdrawReserves)
        //get the liquidity tokens
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        uint256 shares = store.balanceOf[address(this)];
        require(shares > 0, '0 shares');

        updateIndex(store);

        require((assets = _previewRedeem(store, shares)) <= store.LP_TOKEN_BALANCE, '> liq');

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call strategy and ask strategy to use callback to transfer to CFMM then strategy calls burn
        //Bal/Crv: U -> GP -> Strategy -> CFMM -> Strategy -> U
        //                    just call strategy and ask strategy to use callback to transfer to Strategy then to CFMM
        //                    Since CFMM has to pull from strategy, strategy must always check it has enough approval
        reserves = withdrawFromCFMM(store.cfmm, to, assets);
        _burn(store, address(this), shares);

        store.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(store.cfmm, address(this));
        //emit Burn(msg.sender, _amount0, _amount1, uniLiquidity, to);
    }


    //*************ERC-4626 functions************//

    function _deposit(uint256 assets, address to) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        // Check for rounding error since we round down in previewDeposit.
        require((shares = _previewDeposit(store, assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        GammaSwapLibrary.safeTransferFrom(store.cfmm, msg.sender, address(this), assets);

        _mint(store, to, shares);

        emit Deposit(msg.sender, to, assets, shares);

        afterDeposit(store, assets, shares);
    }

    function _mint(uint256 shares, address to) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        assets = _previewMint(store, shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        GammaSwapLibrary.safeTransferFrom(store.cfmm, msg.sender, address(this), assets);

        _mint(store, to, shares);

        emit Deposit(msg.sender, to, assets, shares);

        afterDeposit(store, assets, shares);
    }

    function _withdraw(uint256 assets, address to, address from) external virtual override lock returns(uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        require(assets <= store.LP_TOKEN_BALANCE, '> liq');

        shares = _previewWithdraw(store, assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != from) {
            uint256 allowed = store.allowance[from][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) store.allowance[from][msg.sender] = allowed - shares;
        }

        beforeWithdraw(store, assets, shares);

        _burn(store, from, shares);

        emit Withdraw(msg.sender, to, from, assets, shares);

        GammaSwapLibrary.safeTransfer(store.cfmm, to, assets);
    }

    function _redeem(uint256 shares, address to, address from) external virtual override lock returns(uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        updateIndex(store);

        if (msg.sender != from) {
            uint256 allowed = store.allowance[from][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) store.allowance[from][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = _previewRedeem(store, shares)) != 0, "ZERO_ASSETS");
        require(assets <= store.LP_TOKEN_BALANCE, '> liq');

        beforeWithdraw(store, assets, shares);

        _burn(store, from, shares);

        emit Withdraw(msg.sender, to, from, assets, shares);

        GammaSwapLibrary.safeTransfer(store.cfmm, to, assets);
    }

    //ACCOUNTING LOGIC

    function _previewDeposit(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = store.LP_TOKEN_TOTAL;

        //return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
        return supply == 0 ? assets : (assets * supply) / _totalAssets;
    }

    function _previewMint(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = store.LP_TOKEN_TOTAL;

        //return supply == 0 ? shares : shares.mulDivUp(_totalAssets, supply);
        return supply == 0 ? shares : (shares * _totalAssets) / supply;
    }

    function _previewWithdraw(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = store.LP_TOKEN_TOTAL;

        //return supply == 0 ? assets : assets.mulDivUp(supply, _totalAssets);
        return supply == 0 ? assets : (assets * supply) / _totalAssets;
    }

    function _previewRedeem(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = store.totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint256 _totalAssets = store.LP_TOKEN_TOTAL;

        //return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
        return supply == 0 ? shares : (shares * _totalAssets) / supply;
    }

    //INTERNAL HOOKS LOGIC

    function beforeWithdraw(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}
}
