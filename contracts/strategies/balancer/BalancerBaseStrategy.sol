// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/rates/LogDerivativeRateModel.sol";
import "@gammaswap/v1-core/contracts/strategies/BaseStrategy.sol";
import "@gammaswap/v1-core/contracts/libraries/Math.sol";
import "../../interfaces/external/balancer/IVault.sol";
import "../../interfaces/external/balancer/IWeightedPool.sol";
import "../../interfaces/strategies/IBalancerStrategy.sol";
import "../../libraries/weighted/WeightedMath.sol";
import "../../libraries/weighted/InputHelpers.sol";

/// @title Base Strategy abstract contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer and inherits LogDerivativeRateModel
abstract contract BalancerBaseStrategy is IBalancerStrategy, BaseStrategy, LogDerivativeRateModel {

    using LibStorage for LibStorage.Storage;
    using FixedPoint for uint256;

    error MaxTotalApy();
    error BAL311();

    /// @dev Number of blocks network will issue within a ear. Currently expected
    uint256 immutable public BLOCKS_PER_YEAR; // 2628000 blocks per year in ETH mainnet (12 seconds per block)

    /// @dev Max total annual APY the GammaPool will charge liquidity borrowers (e.g. 1,000%).
    uint256 immutable public MAX_TOTAL_APY;

    /// @dev Weight of token0 in the Balancer pool.
    uint256 immutable public weight0;

    /// @dev Weight of token1 in the Balancer pool.
    uint256 immutable public weight1;

    /// @dev Initializes the contract by setting `_maxTotalApy`, `_blocksPerYear`, `_baseRate`, `_factor`, `_maxApy`, and `_weight0`
    constructor(uint256 _maxTotalApy, uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0) LogDerivativeRateModel(_baseRate, _factor, _maxApy) {
        if(_maxTotalApy < _maxApy) { // maxTotalApy (CFMM Fees + GammaSwap interest rate) cannot be greater or equal to maxApy (max GammaSwap interest rate)
            revert MaxTotalApy();
        }
        MAX_TOTAL_APY = _maxTotalApy;
        BLOCKS_PER_YEAR = _blocksPerYear;
        weight0 = _weight0;
        weight1 = 1e18 - _weight0;
    }

    /// @dev See {BaseStrategy-blocksPerYear}.
    function blocksPerYear() internal virtual override view returns(uint256) {
        return BLOCKS_PER_YEAR;
    }

    /// @dev See {BaseStrategy-maxTotalApy}.
    function maxTotalApy() internal virtual override view returns(uint256) {
        return MAX_TOTAL_APY;
    }

    /// @dev Returns the address of the Balancer Vault contract attached to a given Balancer pool.
    function getVault() internal virtual view returns(address) {
        return s.getAddress(uint256(StorageIndexes.VAULT));
    }

    /// @dev Returns the pool ID of a given Balancer pool.
    function getPoolId() internal virtual view returns(bytes32) {
        return s.getBytes32(uint256(StorageIndexes.POOL_ID));
    }

    /// @dev Returns the swap fee percentage of a given Balancer pool.
    /// @param cfmm The contract address of the Balancer weighted pool.
    function getSwapFeePercentage(address cfmm) internal virtual view returns(uint256) {
        return IWeightedPool(cfmm).getSwapFeePercentage();
    }

    /// @dev Returns the scaling factors of a given Balancer pool based on stored values.
    function getScalingFactors() internal virtual view returns(uint256 factor0, uint256 factor1) {
        factor0 = s.getUint256(uint256(StorageIndexes.SCALING_FACTOR0));
        factor1 = s.getUint256(uint256(StorageIndexes.SCALING_FACTOR1));
    }

    /// @dev Returns the quantities of reserve tokens held by the GammaPool contract.
    function getStrategyReserves() internal virtual view returns(uint256 reserves0, uint256 reserves1) {
        reserves0 = GammaSwapLibrary.balanceOf(IERC20(s.tokens[0]), address(this));
        reserves1 = GammaSwapLibrary.balanceOf(IERC20(s.tokens[1]), address(this));
    }

    /// @dev Checks whether the GammaPool contract has sufficient allowance to interact with the Balancer Vault contract.
    ///     If not, approves the Vault contract to spend the required amount.
    /// @param token The address of the ERC20 token requiring approval.
    /// @param amount The amount required to approve.
    function addVaultApproval(address token, uint256 amount) internal {
        address vault = getVault();
        if (IERC20(token).allowance(address(this), vault) < amount) {
            // Approve the maximum amount
            IERC20(token).approve(vault, type(uint256).max);
        }
    }

    /// @dev See {BaseStrategy-updateReserves}.
    function updateReserves(address) internal virtual override {
        (,uint256[] memory reserves, ) = IVault(getVault()).getPoolTokens(getPoolId());
        s.CFMM_RESERVES[0] = uint128(reserves[0]);
        s.CFMM_RESERVES[1] = uint128(reserves[1]);
    }

    /// @dev See {BaseStrategy-depositToCFMM}.
    function depositToCFMM(address _cfmm, address to, uint256[] memory amounts) internal virtual override returns(uint256) {
        // We need to encode userData for the joinPool call
        address[] memory tokens = s.tokens;

        // Adding approval for the Vault to spend the tokens
        addVaultApproval(tokens[0], amounts[0]);
        addVaultApproval(tokens[1], amounts[1]);

        // Log the LP token balance of the GammaPool
        uint256 initialBalance = GammaSwapLibrary.balanceOf(IERC20(_cfmm), address(this));

        IVault(getVault()).joinPool(getPoolId(),
            address(this), // The GammaPool is sending the reserve tokens
            to,
            IVault.JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: amounts,
                userData: abi.encode(1, amounts, 0),
                fromInternalBalance: false
                })
            );

        // Return the difference in LP token balance of the GammaPool
        return GammaSwapLibrary.balanceOf(IERC20(_cfmm), address(this)) - initialBalance;
    }

    /// @dev See {BaseStrategy-withdrawFromCFMM}.
    function withdrawFromCFMM(address, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        // Log the initial reserves in the GammaPool
        (uint256 initialReserves0, uint256 initialReserves1) = getStrategyReserves();

        IVault(getVault()).exitPool(getPoolId(),
            address(this), // The GammaPool is sending the Balancer LP tokens
            payable(to), // Recipient of pool reserve tokens
            IVault.ExitPoolRequest({
                assets: s.tokens,
                minAmountsOut: new uint256[](2),
                userData: abi.encode(1, amount), // We need to encode userData for the exitPool call
                toInternalBalance: false})
            );

        // Log the final reserves in the GammaPool
        (uint256 finalReserves0, uint256 finalReserves1) = getStrategyReserves();

        // Note: We are logging differences in reserves of the GammaPool (instead of the Vault) to account for transfer tax on the underlying tokens

        // The difference between the initial and final reserves is the amount of reserve tokens withdrawn
        amounts = new uint256[](2);
        amounts[0] = finalReserves0 - initialReserves0;
        amounts[1] = finalReserves1 - initialReserves1;
    }

    /// @dev See {BaseStrategy-calcInvariant}.
    function calcInvariant(address, uint128[] memory amounts) internal virtual override view returns(uint256) {
        (uint256 factor0, uint256 factor1) = getScalingFactors();
        uint256[] memory scaledReserves = new uint256[](2);
        scaledReserves[0] = amounts[0] * factor0;
        scaledReserves[1] = amounts[1] * factor1;
        return calcScaledInvariant(scaledReserves);
    }

    /// @dev Calculated invariant from amounts scaled to 18 decimals
    /// @param amounts - reserve amounts used to calculate invariant
    /// @return invariant - calculated invariant for Balancer AMM
    function calcScaledInvariant(uint256[] memory amounts) internal virtual view returns(uint256 invariant) {
        invariant = FixedPoint.ONE.mulDown(amounts[0].powDown(weight0)).mulDown(amounts[1].powDown(weight1));
        if(invariant == 0) {
            revert BAL311();
        }
    }
}
