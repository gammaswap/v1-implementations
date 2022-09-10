// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./GammaPoolERC20.sol";
import "../libraries/GammaSwapLibrary.sol";
//import {SafeTransferLib} from "../utils/SafeTransferLib.sol";
//import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

abstract contract GammaPoolERC4626 is GammaPoolERC20 {
    //using SafeTransferLib for GammaPoolERC20;
    //using FixedPointMathLib for uint256;

    //IMMUTABLES

    constructor() {
    }

    function asset() public virtual returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    //TODO: DEPOSIT/WITHDRAWAL LOGIC

    function deposit(uint256 assets, address receiver) external virtual returns (uint256 shares);

    function mint(uint256 shares, address receiver) external virtual returns (uint256 assets);

    function withdraw(uint256 assets, address receiver, address owner) external virtual returns (uint256 shares);

    function redeem(uint256 shares, address receiver, address owner) external virtual returns (uint256 assets);

    //ACCOUNTING LOGIC - readonly

    function totalAssets() public view virtual returns (uint256);//This has to be defined. Total quantity of LP Tokens (readonly) in GammaPool

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

}