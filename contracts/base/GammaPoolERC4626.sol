pragma solidity ^0.8.0;

import "./GammaPoolERC20.sol";
import "../libraries/GammaSwapLibrary.sol";
//import {SafeTransferLib} from "../utils/SafeTransferLib.sol";
//import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

abstract contract GammaPoolERC4626 is GammaPoolERC20 {
    //using SafeTransferLib for GammaPoolERC20;
    //using FixedPointMathLib for uint256;

    //EVENTS

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    //IMMUTABLES

    //IERC20 public immutable asset;//This is the LPToken

    constructor() {
    }

    function asset() public virtual returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    //TODO: DEPOSIT/WITHDRAWAL LOGIC

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        //TODO: Need update of interest rate here. Maybe should move it all to ShortStrategy then and make this delegated calls, except for the readonly functions (those only totalAssets would be delegated)
        // Check for rounding error since we round down in previewDeposit.
        require((shares = _previewDeposit(store, assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        GammaSwapLibrary.safeTransferFrom(store.cfmm, msg.sender, address(this), assets);

        _mint(store, receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(store, assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        //TODO: Need update of interest rate here. Maybe should move it all to ShortStrategy then and make this delegated calls, except for the readonly functions (those only totalAssets would be delegated)
        assets = _previewMint(store, shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        GammaSwapLibrary.safeTransferFrom(store.cfmm, msg.sender, address(this), assets);

        _mint(store, receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(store, assets, shares);
    }/**/

    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        require(assets < store.LP_TOKEN_BALANCE, '> liq');
        //TODO: Need update of interest rate here. Maybe should move it all to ShortStrategy then and make this delegated calls, except for the readonly functions (those only totalAssets would be delegated)
        shares = _previewWithdraw(store, assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = store.allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) store.allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(store, assets, shares);

        _burn(store, owner, shares);//TODO: Must check there's enough to burn

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        GammaSwapLibrary.safeTransfer(store.cfmm, receiver, assets);
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256 assets) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();

        //TODO: Need update of interest rate here. Maybe should move it all to ShortStrategy then and make this delegated calls, except for the readonly functions (those only totalAssets would be delegated)
        if (msg.sender != owner) {
            uint256 allowed = store.allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) store.allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = _previewRedeem(store, shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(store, assets, shares);

        _burn(store, owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        GammaSwapLibrary.safeTransfer(store.cfmm, receiver, assets);
    }/**/

    //ACCOUNTING LOGIC
    function _totalAssets() internal view virtual returns (uint256);//This has to be defined. Total quantity of LP Tokens in GammaPool

    function _convertToShares(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function _convertToAssets(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function _previewDeposit(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function _previewMint(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function _previewWithdraw(GammaPoolStorage.Store storage store, uint256 assets) internal view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function _previewRedeem(GammaPoolStorage.Store storage store, uint256 shares) internal view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    //ACCOUNTING LOGIC - readonly

    function totalAssets() public view virtual returns (uint256);//This has to be defined. Total quantity of LP Tokens in GammaPool

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        //return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    //DEPOSIT/WITHDRAWAL LIMIT LOGIC

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(GammaPoolStorage.store().balanceOf[owner]);
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return GammaPoolStorage.store().balanceOf[owner];
    }

    //INTERNAL HOOKS LOGIC

    function beforeWithdraw(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(GammaPoolStorage.Store storage store, uint256 assets, uint256 shares) internal virtual {}
}