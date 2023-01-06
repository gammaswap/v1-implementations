// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/external/IVault.sol";
import "../../interfaces/external/IWeightedPool2Tokens.sol";
import "../../libraries/Math.sol";
import "../../rates/LogDerivativeRateModel.sol";
import "../base/BaseStrategy.sol";

abstract contract BalancerBaseStrategy is BaseStrategy, LogDerivativeRateModel {
    // Add the vault address as immutable to the contract
    address private immutable vault;

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy, address _vault) LogDerivativeRateModel(_baseRate, _factor, _maxApy) {
        vault = _vault;
    }

    function getPoolId(address cfmm) internal virtual view returns(bytes32 poolId) {
        bytes32 poolId = IWeightedPool2Tokens(cfmm).getPoolId();
    }

    /**
     * @dev Updates the storage variable CFMM_RESERVES for a given vault and Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function updateReserves(address cfmm) internal virtual override {
        uint[] memory reserves = new uint[](2);
        (, reserves, ) = IVault(vault).getPoolTokens(getPoolId(cfmm));

        // TODO: Is this casting safe?
        s.CFMM_RESERVES[0] = uint128(reserves[0]);
        s.CFMM_RESERVES[1] = uint128(reserves[1]);
    }

    function getReserves(address cfmm) internal virtual view returns(uint128[]) {
        uint[] memory poolReserves = new uint[](2);
        (, poolReserves, ) = IVault(vault).getPoolTokens(getPoolId(cfmm));

        // TODO: Do I need to cast reserves to uint128[]?
        uint128[] memory reserves = new uint128[](2);
        reserves[0] = uint128(poolReserves[0]);
        reserves[1] = uint128(poolReserves[1]);

        return reserves;
    }

    function getTokens(address cfmm) internal virtual view returns(address[]) {
        address[] memory tokens = new address[](2);
        IERC20[] memory _tokens = new IERC20[](2);

        (_tokens, , ) = IVault(vault).getPoolTokens(getPoolId(cfmm));

        // TODO: Improve this handling of casting from IERC20 to address
        tokens[0] = address(_tokens[0]);
        tokens[1] = address(_tokens[1]);

        return tokens
    }

    function getWeights(address cfmm) internal virtual view returns(uint256[]) {
        uint256[] memory weights = new uint256[](2);
        (weights[0], weights[1]) = IWeightedPool2Tokens(cfmm).getNormalizedWeights();
        return weights
    }

    /**
     * @dev Deposits reserves into the Balancer Vault contract.
     *      Calls joinPool on the Vault contract and mints the BPT token to the GammaPool.
     * @param cfmm The address of the Balancer pool/LP token.
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
                IVault.JoinPoolRequest({assets: getTokens(cfmm), maxAmountsIn: amounts, userData: userDataEncoded, fromInternalBalance: false}) // JoinPoolRequest is a struct, and is expected as input for the joinPool function
                );

        return 1;
    }

    /**
     * @dev Withdraws reserves from the Balancer Vault contract.
     *      Sends the Vault contract the BPT tokens and receives the pool reserve tokens.
     * @param cfmm The address of the Balancer pool/LP token.
     * @param to The address to return the pool reserve tokens to.
     * @param amount The amount of Balancer LP token to burn.
     */    
    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        // We need to encode userData for the exitPool call
        bytes memory userDataEncoded = abi.encode(1, amount);

        // Notes from Balancer Documentation:
        // When providing your assets, you must ensure that the tokens are sorted numerically by token address. 
        // It's also important to note that the values in minAmountsOut correspond to the same index value in assets, 
        // so these arrays must be made in parallel after sorting.

        // Log the initial reserves in the pool
        uint128[] memory initialReserves = getReserves(cfmm);

        uint[] memory minAmountsOut = new uint[](2);

        IVault(vault).exitPool(getPoolId(cfmm), 
                to, // The GammaPool is sending the Balancer LP tokens
                payable(to), // The user is receiving the pool reserve tokens
                IVault.ExitPoolRequest({assets: getTokens(cfmm), minAmountsOut: minAmountsOut, userData: userDataEncoded, toInternalBalance: false})
                );

        // Must return amounts as an array of withdrawn reserves
        uint128[] memory finalReserves = getReserves(cfmm);

        amounts[0] = uint256(finalReserves[0] - initialReserves[0]);
        amounts[1] = uint256(finalReserves[1] - initialReserves[1]);
    }

    /**
     * @dev Calculates the Balancer invariant for a given Balancer pool and reserve amounts.
     * @param cfmm The contract address of the Balancer weighted pool.
     * @param amounts The pool reserves to use in the calculation.
     */
    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual override view returns(uint256 invariant) {
        uint256[] memory weights = getWeights(cfmm);
        invariant = Math.power(amounts[0], weights[0]) * Math.power(amounts[1], weights[1]);
    }
}
