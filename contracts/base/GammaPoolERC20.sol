// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

abstract contract GammaPoolERC20 {

    /*event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address account) external view returns (uint256 bal) {
        bal = _balanceOf[account];
    }

    function allowance(address owner, address spender) external view returns (uint256 bal) {
        bal = _allowance[owner][spender];
    }

    function _approve(address owner, address spender, uint value) private {
        _allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        _balanceOf[from] = _balanceOf[from] - value;
        _balanceOf[to] = _balanceOf[to] + value;
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
        if (_allowance[from][msg.sender] != type(uint).max) {
            _allowance[from][msg.sender] = _allowance[from][msg.sender] - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(amount > 0, '0 amt');
        totalSupply += amount;
        _balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "0 address");
        uint256 accountBalance = _balanceOf[account];
        require(accountBalance >= amount, "> balance");
        unchecked {
            _balanceOf[account] = accountBalance - amount;
        }
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }/**/
}
