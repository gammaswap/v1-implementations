// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCFMM is ERC20 {

    address public token0;
    address public token1;
    uint112 public reserves0;
    uint112 public reserves1;

    constructor(address _token0, address _token1, string memory name, string memory symbol) ERC20(name, symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    function sync() public virtual {
        reserves0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserves1 = uint112(IERC20(token1).balanceOf(address(this)));
    }

    function getReserves() public virtual view returns(uint112, uint112, uint32){
        return(reserves0, reserves1, 0);
    }

    function mint(uint256 shares, address to) public virtual {
        _mint(to, shares);
    }

    function burn(uint256 shares, address to) public virtual {
        _burn(to, shares);
    }
}
