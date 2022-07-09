// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IGammaPool is IERC20 {

    function tokens() external view returns(address[] memory);
    function cfmm() external view returns(address);
    function mint(address to) external returns(uint);
    function burn(address to) external returns(uint[] memory);
    function addLiquidity(uint[] calldata amountsDesired, uint[] calldata amountsMin, bytes calldata data) external returns(uint[] memory);

}
