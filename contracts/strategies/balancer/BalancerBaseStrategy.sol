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

    function getPoolId(address cfmm) internal virtual override view returns(bytes32 poolId) {
        bytes32 poolId = IWeightedPool2Tokens(cfmm).getPoolId();
        return poolId;
    }

    /**
     * @dev Updates the storage variable CFMM_RESERVES for a given vault and Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function updateReserves(address cfmm) internal virtual override {
        poolId = IWeightedPool2Tokens(cfmm).getPoolId();
        (, , s.CFMM_RESERVES[0], s.CFMM_RESERVES[1]) = IVault(vault).getPoolTokens(getPoolId(cfmm));
    }

    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (, , reserves[0], reserves[1]) = IVault(vault).getPoolTokens(getPoolId(cfmm));
    }

    function getTokens(address cfmm) internal virtual override view returns(address[] memory tokens) {
        tokens = new address[](2);
        (tokens[0], tokens[1], , ) = IVault(vault).getPoolTokens(getPoolId(cfmm));
    }

    function getWeights(address cfmm) internal virtual override view returns(uint128[] memory weights) {
        weights = new uint128[](2);
        (weights[0], weights[1]) = IWeightedPool2Tokens(cfmm).getNormalizedWeights();
    }

    /**
     * @dev Deposits reserves into the Balancer Vault contract.
     *      Calls joinPool on the Vault contract and mints the BPT token to the GammaPool.
     * @param cfmm The amount of token removed from the pool during the swap.
     * @param amounts The amounts of each pool token to deposit.
     * @param to The address to mint the Balancer LP tokens to.
     */
    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256) {
        // We need to encode userData for the joinPool call
        uint256 minimumBPT = 0; // TODO: Do I need to estimate this?
        bytes memory userDataEncoded = abi.encode(1, amounts, minimumBPT);

        IVault(vault).joinPool(getPoolId(cfmm), 
                to, // The GammaPool is sending the tokens
                to, // The GammaPool is receiving the Balancer LP tokens
                {
                    assets: getTokens(cfmm),
                    maxAmountsIn: amounts,
                    userData: userDataEncoded,
                    fromInternalBalance: false
                });

        return 1;
    }

    /**
     * @dev todo
     * @param cfmm todo
     * @param to todo
     * @param amount todo
     */    
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
        (weights[0], weights[1]) = getWeights(cfmm);

        invariant = FixedPoint.ONE;

        for (uint256 i = 0; i < weights.length; i++) {
            invariant = invariant.mulDown(amounts[i].powDown(weights[i]));
        }

        return invariant;
    }
}
