// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./IPositionManager.sol";

interface IProtocolRouter {

    function addLiquidity(IPositionManager.AddLiquidityParams calldata params, address to, bytes calldata data) external returns (uint amountA, uint amountB, uint liquidity, address pool);
}
