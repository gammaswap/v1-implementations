// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/rates/LogDerivativeRateModel.sol";
import "@gammaswap/v1-core/contracts/strategies/BaseStrategy.sol";
import "@gammaswap/v1-core/contracts/libraries/Math.sol";
import "../../interfaces/external/balancer/IVault.sol";
import "../../interfaces/external/balancer/IWeightedPool.sol";
import "../../libraries/weighted/WeightedMath.sol";
import "../../libraries/weighted/InputHelpers.sol";

/**
 * @title Base Strategy abstract contract for Balancer Weighted Pools
 * @author JakeXBT (https://github.com/JakeXBT)
 * @notice Common functions used by all concrete strategy implementations for Balancer Weighted Pools
 * @dev This implementation was specifically designed to work with Balancer and inherits LogDerivativeRateModel
 */
abstract contract BalancerBaseStrategy is BaseStrategy, LogDerivativeRateModel {

    error MaxTotalApy();

    /// @dev Number of blocks network will issue within a ear. Currently expected
    uint256 immutable public BLOCKS_PER_YEAR; // 2628000 blocks per year in ETH mainnet (12 seconds per block)

    /// @dev Max total annual APY the GammaPool will charge liquidity borrowers (e.g. 1,000%).
    uint256 immutable public MAX_TOTAL_APY;

    /// @dev Initializes the contract by setting `_maxTotalApy`, `_blocksPerYear`, `_baseRate`, `_factor`, and `_maxApy`
    constructor(uint256 _maxTotalApy, uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy) LogDerivativeRateModel(_baseRate, _factor, _maxApy) {
        if(_maxTotalApy < _maxApy) { // maxTotalApy (CFMM Fees + GammaSwap interest rate) cannot be greater or equal to maxApy (max GammaSwap interest rate)
            revert MaxTotalApy();
        }
        MAX_TOTAL_APY = _maxTotalApy;
        BLOCKS_PER_YEAR = _blocksPerYear;
    }

    /**
     * @dev See {BaseStrategy-blocksPerYear}.
     */
    function blocksPerYear() internal virtual override view returns(uint256) {
        return BLOCKS_PER_YEAR;
    }

    /**
     * @dev See {BaseStrategy-maxTotalApy}.
     */
    function maxTotalApy() internal virtual override view returns(uint256) {
        return MAX_TOTAL_APY;
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
     * @dev Checks whether the GammaPool contract has sufficient allowance to interact with the Balancer Vault contract.
     *      If not, approves the Vault contract to spend the required amount.
     * @param token The address of the ERC20 token requiring approval.
     * @param amount The amount required to approve.
     */
    function addVaultApproval(address token, uint256 amount) internal {
        address cfmm = s.cfmm;
        uint256 allowance = IERC20(token).allowance(address(this), getVault(cfmm));
        if (allowance < amount) {
            // Approve the maximum amount
            IERC20(token).approve(getVault(cfmm), type(uint256).max);
        }
    }


    /// @dev See {BaseStrategy-updateReserves}.
    function updateReserves(address cfmm) internal virtual override {
        uint128[] memory reserves = getPoolReserves(cfmm);
        s.CFMM_RESERVES[0] = reserves[0];
        s.CFMM_RESERVES[1] = reserves[1];
    }

    /// @dev See {BaseStrategy-depositToCFMM}.
    function depositToCFMM(address cfmm, address to, uint256[] memory amounts) internal virtual override returns(uint256) {
        // We need to encode userData for the joinPool call
        bytes memory userDataEncoded = abi.encode(1, amounts, 0);

        address vaultId = getVault(cfmm);
        bytes32 poolId = getPoolId(cfmm);

        address[] memory tokens = getTokens(cfmm);

        // Adding approval for the Vault to spend the tokens
        addVaultApproval(tokens[0], amounts[0]);
        addVaultApproval(tokens[1], amounts[1]);

        // Log the LP token balance of the GammaPool
        uint256 initialBalance = GammaSwapLibrary.balanceOf(IERC20(cfmm), address(this));

        IVault(vaultId).joinPool(poolId,
            address(this), // The GammaPool is sending the reserve tokens
            to,
            IVault.JoinPoolRequest(
                {
                assets: tokens,
                maxAmountsIn: amounts,
                userData: userDataEncoded,
                fromInternalBalance: false
                })
            );

        // Return the difference in LP token balance of the GammaPool
        return GammaSwapLibrary.balanceOf(IERC20(cfmm), address(this)) - initialBalance;
    }


    /// @dev See {BaseStrategy-withdrawFromCFMM}.
    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory) {
        // We need to encode userData for the exitPool call
        bytes memory userDataEncoded = abi.encode(1, amount);

        // Log the initial reserves in the GammaPool
        uint256[] memory initialReserves = getStrategyReserves();

        uint[] memory minAmountsOut = new uint[](2);

        IVault(getVault(cfmm)).exitPool(getPoolId(cfmm), 
            address(this), // The GammaPool is sending the Balancer LP tokens
            payable(to), // Recipient of pool reserve tokens
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


    /// @dev See {BaseStrategy-calcInvariant}.
    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual override view returns(uint256) {
        uint256[] memory weights = getWeights(cfmm);

        uint256[] memory scalingFactors = InputHelpers.getScalingFactors(getTokens(cfmm));
        uint256[] memory scaledAmounts = InputHelpers.upscaleArray(InputHelpers.castToUint256Array(amounts), scalingFactors);

        return WeightedMath._calculateInvariant(weights, scaledAmounts);
    }

}
