// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IGammaPool is IERC20 {

    function mint(uint totalCFMMInvariant, uint newInvariant, address to) external returns(uint256 liquidity);

}
