// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../DepositPool.sol";

contract TestDepositPool is DepositPool {

    constructor(address _uniRouter, address _uniPair, address _token0, address _token1, address _positionManager)
        DepositPool(_uniRouter, _uniPair, _token0, _token1, _positionManager) {
    }

    function setBaseRate(uint256 baseRate) public {
        BASE_RATE = baseRate;
    }

    function setOptimalUtilizationRate(uint256 optimalUtilizationRate) public {
        OPTIMAL_UTILIZATION_RATE = optimalUtilizationRate;
    }

    function setSlope1(uint256 slope1) public {
        SLOPE1 = slope1;
    }

    function setSlope2(uint256 slope2) public {
        SLOPE2 = slope2;
    }

    function swapExactTokens4Tokens(address _token0, address _token1, uint256 amount, uint256 amountOutMin, address recipient) public {
        //address _uniRouter = IVegaswapV1Factory(factory).uniRouter();
        if(amount > IERC20(_token0).allowance(address(this), uniRouter)) {
            IERC20(_token0).approve(uniRouter, type(uint).max);
        }
        swapExactTokensForTokens(_token0, _token1, amountOutMin, amount, recipient);/**/
    }
}
