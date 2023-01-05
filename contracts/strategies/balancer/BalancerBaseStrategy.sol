// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";

import "../../interfaces/external/IVault.sol";
import "../../interfaces/external/IWeightedPool2Tokens.sol";
import "../../libraries/Math.sol";
import "../../rates/LogDerivativeRateModel.sol";
import "../base/BaseStrategy.sol";

abstract contract BalancerBaseStrategy is BaseStrategy, LogDerivativeRateModel {
    // Use Balancer's fixed point math library for integers
    using FixedPoint for uint256;

    // Add the vault address as immutable to the contract
    address private immutable vault;

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy, address _vault) LogDerivativeRateModel(_baseRate, _factor, _maxApy) {
        vault = _vault;
    }

    /**
     * @dev Updates the storage variable CFMM_RESERVES for a given vault and Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function updateReserves(address cfmm) internal virtual override {
        poolId = IWeightedPool2Tokens(cfmm).getPoolId();
        (, , s.CFMM_RESERVES[0], s.CFMM_RESERVES[1]) = IVault(vault).getPoolTokens(poolId);
    }

    // TODO: Implement the correct deposit logic for Balancer pools
    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256) {
        return 1;
    }

    // TODO: Implement the correct withdraw logic for Balancer pools
    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        return 1;
    }

    /**
     * @dev Calculates the Balancer invariant for a given Balancer pool and reserve amounts.
     * @param cfmm The contract address of the Balancer weighted pool.
     * @param amounts The pool reserves to use in the calculation.
     */
    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual override view returns(uint256) {
        weights = new uint[](2);
        (weights[0], weights[1]) = IWeightedPool2Tokens(cfmm).getNormalizedWeights();

        invariant = FixedPoint.ONE;

        for (uint256 i = 0; i < weights.length; i++) {
            invariant = invariant.mulDown(amounts[i].powDown(weights[i]));
        }

        return invariant;
    }
}
