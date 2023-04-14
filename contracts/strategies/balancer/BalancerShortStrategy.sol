// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/ShortStrategySync.sol";
import "../../interfaces/external/balancer/IVault.sol";
import "./BalancerBaseStrategy.sol";

/// @title Short Strategy concrete implementation contract for Balancer Weighted Pools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by ShortStrategy and defines internal functions specific to Balancer Weighted Pools
/// @dev This implementation was specifically designed to work with Balancer
contract BalancerShortStrategy is BalancerBaseStrategy, ShortStrategySync {
    error ZeroDeposits();
    error NotOptimalDeposit();
    error ZeroReserves();
    error LengthMismatch();

    /// @dev Initializes the contract by setting `_maxTotalApy`, `_blocksPerYear`, `_baseRate`, `_factor`, `_maxApy`, and `_weight0`
    constructor(uint256 _maxTotalApy, uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0)
        BalancerBaseStrategy(_maxTotalApy, _blocksPerYear, _baseRate, _factor, _maxApy, _weight0) {
    }

    /// @dev See {IShortStrategy-_getLatestCFMMReserves}.
    function _getLatestCFMMReserves(bytes memory _data) public virtual override view returns(uint128[] memory reserves) {
        // Decode the PoolId in this function
        BalancerReservesRequest memory req = abi.decode(_data, (BalancerReservesRequest));
        (,uint256[] memory _reserves,) = IVault(req.cfmmVault).getPoolTokens(req.cfmmPoolId);
        reserves = new uint128[](2);
        reserves[0] = uint128(_reserves[0]);
        reserves[1] = uint128(_reserves[1]);
    }

    /// @dev See {IShortStrategy-_getLatestCFMMInvariant}.
    function _getLatestCFMMInvariant(bytes memory _data) public virtual override view returns(uint256 cfmmInvariant) {
        BalancerInvariantRequest memory req = abi.decode(_data, (BalancerInvariantRequest));
        (,uint256[] memory reserves,) = IVault(req.cfmmVault).getPoolTokens(req.cfmmPoolId);

        if (reserves.length != req.scalingFactors.length) {
            revert LengthMismatch();
        }
        reserves[0] *= req.scalingFactors[0];
        reserves[1] *= req.scalingFactors[1];
        cfmmInvariant = calcScaledInvariant(reserves);
    }

    /// @dev Returns the pool reserves of a given Balancer pool, obtained by querying the corresponding Balancer Vault.
    function getReserves(address) internal virtual override view returns(uint128[] memory reserves) {
        (,uint256[] memory _reserves,) = IVault(getVault()).getPoolTokens(getPoolId());
        reserves = new uint128[](2);
        reserves[0] = uint128(_reserves[0]);
        reserves[1] = uint128(_reserves[1]);
    }

    /// @dev Check optimal deposit amount is not less than minimum acceptable deposit amount.
    /// @param amountOptimal Optimal deposit amount.
    /// @param amountMin Minimum deposit amount.
    function checkOptimalAmt(uint256 amountOptimal, uint256 amountMin) internal virtual pure {
        if(amountOptimal < amountMin) {
            revert NotOptimalDeposit();
        }
    }

    /// @dev See {ShortStrategy-calcDepositAmounts}.
    function calcDepositAmounts(uint256[] calldata amountsDesired, uint256[] calldata amountsMin)
            internal virtual override view returns (uint256[] memory amounts, address payee) {
        // Function used to determine the amounts that must be deposited in order to get the LP token one desires
        if(amountsDesired[0] == 0 || amountsDesired[1] == 0) {
            revert ZeroDeposits();
        }

        uint128[] memory reserves = getReserves(address(0));

        // In the case of Balancer, the payee is the GammaPool itself
        payee = address(this);

        if (reserves[0] == 0 && reserves[1] == 0) {
            return(amountsDesired, payee);
        }

        if(reserves[0] == 0 || reserves[1] == 0) {
            revert ZeroReserves();
        }

        amounts = new uint256[](2);

        // Calculates optimal amount as the amount of token1 which corresponds to an amountsDesired of token0
        uint256 optimalAmount1 = (amountsDesired[0] * reserves[1]) / (reserves[0]);
        if (optimalAmount1 <= amountsDesired[1]) {
            checkOptimalAmt(optimalAmount1, amountsMin[1]);
            (amounts[0], amounts[1]) = (amountsDesired[0], optimalAmount1);
            return(amounts, payee);
        }

        uint256 optimalAmount0 = (amountsDesired[1] * reserves[0]) / (reserves[1]);
        assert(optimalAmount0 <= amountsDesired[0]);
        checkOptimalAmt(optimalAmount0, amountsMin[0]);
        (amounts[0], amounts[1]) = (optimalAmount0, amountsDesired[1]);
    }
}
