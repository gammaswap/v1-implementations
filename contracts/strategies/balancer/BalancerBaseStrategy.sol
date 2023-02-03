// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/external/IVault.sol";
import "../../interfaces/external/IWeightedPool.sol";
import "../../libraries/Math.sol";
import "../../libraries/weighted/WeightedMath.sol";
import "../../rates/LogDerivativeRateModel.sol";
import "../base/BaseStrategy.sol";

/**
 * @title Base Strategy abstract contract for Balancer Weighted Pools
 * @author JakeXBT (https://github.com/JakeXBT)
 * @notice Common functions used by all concrete strategy implementations for Balancer Weighted Pools
 * @dev This implementation was specifically designed to work with Balancer and inherits LogDerivativeRateModel
 */
abstract contract BalancerBaseStrategy is BaseStrategy, LogDerivativeRateModel {
    uint256 immutable public BLOCKS_PER_YEAR;

    constructor(uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy) LogDerivativeRateModel(_baseRate, _factor, _maxApy) {
        BLOCKS_PER_YEAR = _blocksPerYear;
    }

    /**
     * @dev See {BaseStrategy-blocksPerYear}.
     */
    function blocksPerYear() internal virtual override view returns(uint256) {
        return BLOCKS_PER_YEAR;
    }

    /**
     * @dev Returns the address of the Balancer Vault contract attached to a given Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function getVault(address cfmm) internal virtual view returns(address) {
        return IWeightedPool(cfmm).getVault();
    }

    /**
     * @dev Returns the pool ID of a given Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function getPoolId(address cfmm) internal virtual view returns(bytes32) {
        bytes32 poolId = IWeightedPool(cfmm).getPoolId();
        return poolId;
    }

    /**
     * @dev Returns the pool reserves of a given Balancer pool, obtained by querying the corresponding Balancer Vault.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function getPoolReserves(address cfmm) internal virtual view returns(uint128[] memory) {
        uint[] memory poolReserves = new uint[](2);
        (, poolReserves, ) = IVault(getVault(cfmm)).getPoolTokens(getPoolId(cfmm));

        uint128[] memory reserves = new uint128[](2);
        reserves[0] = uint128(poolReserves[0]);
        reserves[1] = uint128(poolReserves[1]);

        return reserves;
    }

    /**
     * @dev Returns the reserve token addresses of a given Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function getTokens(address cfmm) internal virtual view returns(address[] memory) {
        address[] memory tokens = new address[](2);
        IERC20[] memory _tokens = new IERC20[](2);

        (_tokens, , ) = IVault(getVault(cfmm)).getPoolTokens(getPoolId(cfmm));

        tokens[0] = address(_tokens[0]);
        tokens[1] = address(_tokens[1]);

        return tokens;
    }

    /**
     * @dev Returns the normalized weights of a given Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function getWeights(address cfmm) internal virtual view returns(uint256[] memory) {
        uint256[] memory weights = IWeightedPool(cfmm).getNormalizedWeights();
        return weights;
    }

    /**
     * @dev Returns the quantities of reserve tokens held by the GammaPool contract.
     */
    function getStrategyReserves() internal virtual view returns(uint256[] memory) {
        address[] memory tokens = getTokens(s.cfmm);

        uint256[] memory reserves = new uint256[](2);
        reserves[0] = IERC20(tokens[0]).balanceOf(address(this));
        reserves[1] = IERC20(tokens[1]).balanceOf(address(this));
        return reserves;
    }

    /**
     * @dev Updates the storage variable CFMM_RESERVES for a given vault and Balancer pool.
     * @param cfmm The contract address of the Balancer weighted pool.
     */
    function updateReserves(address cfmm) internal virtual override {
        uint128[] memory reserves = getPoolReserves(cfmm);
        s.CFMM_RESERVES[0] = reserves[0];
        s.CFMM_RESERVES[1] = reserves[1];
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
        bytes memory userDataEncoded = abi.encode(1, amounts, 0);

        address vaultId = getVault(cfmm);
        bytes32 poolId = getPoolId(cfmm);

        IVault(vaultId).joinPool(poolId, 
                address(this), // The GammaPool is sending the reserve tokens
                address(this), // The GammaPool is receiving the Balancer LP tokens
                IVault.JoinPoolRequest(
                    {
                    assets: getTokens(cfmm), 
                    maxAmountsIn: amounts, 
                    userData: userDataEncoded, 
                    fromInternalBalance: false
                    })
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
    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory) {
        // We need to encode userData for the exitPool call
        bytes memory userDataEncoded = abi.encode(1, amount);

        // Log the initial reserves in the GammaPool
        uint256[] memory initialReserves = getStrategyReserves();
        
        uint[] memory minAmountsOut = new uint[](2);

        IVault(getVault(cfmm)).exitPool(getPoolId(cfmm), 
                to, // The GammaPool is sending the Balancer LP tokens
                payable(to), // The user is receiving the pool reserve tokens
                IVault.ExitPoolRequest({assets: getTokens(cfmm), minAmountsOut: minAmountsOut, userData: userDataEncoded, toInternalBalance: false})
                );

        // Log the final reserves in the GammaPool
        uint256[] memory finalReserves = getStrategyReserves();

        uint256[] memory amounts = new uint256[](2);

        // Note: We are logging differences in reserves of the GammaPool (instead of the Vault) to account for transfer tax on the underlying tokens

        // The difference between the initial and final reserves is the amount of reserve tokens withdrawn
        amounts[0] = finalReserves[0] - initialReserves[0];
        amounts[1] = finalReserves[1] - initialReserves[1];

        return amounts;
    }

    /**
     * @dev Calculates the Balancer invariant for a given Balancer pool and reserve amounts.
     * @param cfmm The contract address of the Balancer weighted pool.
     * @param amounts The pool reserves to use in the calculation.
     */
    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual override view returns(uint256 invariant) {
        uint256[] memory weights = getWeights(cfmm);

        uint256[] memory uint256Amounts = new uint256[](2);
        uint256Amounts[0] = uint256(amounts[0]);
        uint256Amounts[1] = uint256(amounts[1]);

        invariant = WeightedMath._calculateInvariant(weights, uint256Amounts);
    }
}
