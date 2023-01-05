// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../interfaces/external/IVault.sol";
import "../../interfaces/external/IWeightedPool2Tokens.sol";

import "../base/ShortStrategyERC4626.sol";
import "./BalancerBaseStrategy.sol";

import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";

contract BalancerShortStrategy is BalancerBaseStrategy, ShortStrategyERC4626 {
    // Use Balancer's fixed point math library for integers
    using FixedPoint for uint256;

    error ZeroDeposits();
    error NotOptimalDeposit();
    error ZeroReserves();

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy, address _vault)
        BalancerBaseStrategy(_baseRate, _factor, _maxApy, _vault) {

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

        // TODO: Does this contract have access to s.cfmm?
        (uint256 reserve0, uint256 reserve1) = getReserves(s.cfmm);

        // Get normalised weights for price calculation
        (uint256 weight0, uint256 weight1) = getWeights(s.cfmm);

        // In the case of Balancer, the payee is the GammaPool itself
        payee = address(this);

        if (reserve0 == 0 && reserve1 == 0) {
            return(amountsDesired, payee);
        }

        if(reserve0 == 0 || reserve1 == 0) {
            revert ZeroReserves();
        }

        amounts = new uint256[](2);

        // Calculates optimal amount as the amount of token1 which corresponds to an amountsDesired of token0
        // Note: This calculate preserves price, which is almost the same as price in a UniV2 pool

        // TODO: Is there an overflow risk here?
        uint256 optimalAmount1 = (amountsDesired[0] * reserve1 * weight0).divDown(reserve0 * (FixedPoint.ONE - weight1));
        if (optimalAmount1 <= amountsDesired[1]) {
            checkOptimalAmt(optimalAmount1, amountsMin[1]);
            (amounts[0], amounts[1]) = (amountsDesired[0], optimalAmount1);
            return(amounts, payee);
        }

        // TODO: Is there an overflow risk here?
        uint256 optimalAmount0 = (amountsDesired[1] * reserve0 * weight1).divDown(reserve1 * (FixedPoint.ONE - weight0));
        assert(optimalAmount0 <= amountsDesired[0]);
        checkOptimalAmt(optimalAmount0, amountsMin[0]);
        (amounts[0], amounts[1]) = (optimalAmount0, amountsDesired[1]);
    }
}
