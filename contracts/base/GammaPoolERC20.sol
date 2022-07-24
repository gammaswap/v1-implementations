// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/storage/GammaPoolStorage.sol";

abstract contract GammaPoolERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address account) external view returns (uint256) {
        return GammaPoolStorage.store().balanceOf[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return GammaPoolStorage.store().allowance[owner][spender];
    }

    function _approve(address owner, address spender, uint value) private {
        GammaPoolStorage.store().allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        store.balanceOf[from] = store.balanceOf[from] - value;
        store.balanceOf[to] = store.balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        if (store.allowance[from][msg.sender] != type(uint256).max) {
            store.allowance[from][msg.sender] = store.allowance[from][msg.sender] - value;
        }
        _transfer(from, to, value);
        return true;
    }

}
