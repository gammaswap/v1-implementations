// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../interfaces/external/IVault.sol";
import "../../interfaces/external/IWeightedPool.sol";

import "../base/ShortStrategyERC4626.sol";
import "./BalancerBaseStrategy.sol";

import "hardhat/console.sol";

contract BalancerShortStrategy is BalancerBaseStrategy, ShortStrategyERC4626 {
    error ZeroDeposits();
    error NotOptimalDeposit();
    error ZeroReserves();

    constructor(uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseStrategy(_blocksPerYear, _baseRate, _factor, _maxApy) {
    }

    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory) {
        return getPoolReserves(cfmm);
    }

    function checkOptimalAmt(uint256 amountOptimal, uint256 amountMin) internal virtual pure {
        if(amountOptimal < amountMin) {
            revert NotOptimalDeposit();
        }
    }

    function calcDepositAmounts(uint256[] calldata amountsDesired, uint256[] calldata amountsMin)
            internal virtual override view returns (uint256[] memory amounts, address payee) {
        // Function used to determine the amounts that must be deposited in order to get the LP token one desires
        if(amountsDesired[0] == 0 || amountsDesired[1] == 0) {
            revert ZeroDeposits();
        }

        console.log("SC - Calling calcDepositAmounts with arguments", amountsDesired[0], amountsDesired[1]);

        // TODO: Does this contract have access to s.cfmm?
        uint128[] memory reserves = getPoolReserves(s.cfmm);

        console.log("SC - reserves", reserves[0], reserves[1]);

        // Get normalised weights for price calculation
        uint256[] memory weights = getWeights(s.cfmm);

        console.log("SC - weights", weights[0], weights[1]);

        // In the case of Balancer, the payee is the GammaPool itself
        payee = address(this);

        if (reserves[0] == 0 && reserves[1] == 0) {
            return(amountsDesired, payee);
        }

        if(reserves[0] == 0 || reserves[1] == 0) {
            revert ZeroReserves();
        }

        amounts = new uint256[](2);

        console.log("Code went past the zero reserves check");

        // Calculates optimal amount as the amount of token1 which corresponds to an amountsDesired of token0
        // Note: This calculation preserves price, which is almost the same as price in a UniV2 pool

        // TODO: Is there an overflow risk here?
        uint256 optimalAmount1 = (amountsDesired[0] * reserves[1] * weights[0]) / (reserves[0] * weights[1]);
        if (optimalAmount1 <= amountsDesired[1]) {
            checkOptimalAmt(optimalAmount1, amountsMin[1]);
            (amounts[0], amounts[1]) = (amountsDesired[0], optimalAmount1);
            return(amounts, payee);
        }

        // TODO: Is there an overflow risk here?
        uint256 optimalAmount0 = (amountsDesired[1] * reserves[0] * weights[1]) / (reserves[1] * weights[0]);
        assert(optimalAmount0 <= amountsDesired[0]);
        checkOptimalAmt(optimalAmount0, amountsMin[0]);
        (amounts[0], amounts[1]) = (optimalAmount0, amountsDesired[1]);
    }
}
