// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/storage/GammaPoolStorage.sol";

abstract contract GammaPoolERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external virtual view returns (string memory) {
        return GammaPoolStorage.store().symbol;
    }

    function symbol() external virtual view returns (string memory) {
        return GammaPoolStorage.store().symbol;
    }

    function decimals() external virtual view returns (uint8) {
        return GammaPoolStorage.store().decimals;
    }

    function totalSupply() external virtual view returns (uint256) {
        return GammaPoolStorage.store().totalSupply;
    }

    function balanceOf(address account) external virtual view returns (uint256) {
        return GammaPoolStorage.store().balanceOf[account];
    }

    function allowance(address owner, address spender) external virtual view returns (uint256) {
        return GammaPoolStorage.store().allowance[owner][spender];
    }

    function _approve(address owner, address spender, uint value) internal virtual {
        GammaPoolStorage.store().allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(GammaPoolStorage.Store storage store, address from, address to, uint value) internal virtual {
        store.balanceOf[from] = store.balanceOf[from] - value;
        store.balanceOf[to] = store.balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external virtual returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external virtual returns (bool) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _transfer(store, msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external virtual returns (bool) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        if (store.allowance[from][msg.sender] != type(uint256).max) {
            store.allowance[from][msg.sender] = store.allowance[from][msg.sender] - value;
        }
        _transfer(store, from, to, value);
        return true;
    }

}
