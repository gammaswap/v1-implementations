// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../interfaces/external/ICPMM.sol";
import "../base/ShortStrategyERC4626.sol";
import "./CPMMBaseStrategy.sol";

/// @title Short Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz
/// @notice Sets up variables used by ShortStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMShortStrategy is CPMMBaseStrategy, ShortStrategyERC4626 {

    error ZeroDeposits();
    error NotOptimalDeposit();
    error ZeroReserves();

    /// @dev Initializes the contract by setting `_maxTotalApy`, `_blocksPerYear`, `_baseRate`, `_factor`, and `_maxApy`
    constructor(uint256 _maxTotalApy, uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseStrategy(_maxTotalApy, _blocksPerYear, _baseRate, _factor, _maxApy) {
    }

    /// @dev See {IShortStrategy-calcDepositAmounts}.
    function calcDepositAmounts(uint256[] calldata amountsDesired, uint256[] calldata amountsMin)
            internal virtual override view returns (uint256[] memory amounts, address payee) {
        if(amountsDesired[0] == 0 || amountsDesired[1] == 0) { // revert if not depositing one or both sides
            revert ZeroDeposits();
        }

        (uint256 reserve0, uint256 reserve1,) = ICPMM(s.cfmm).getReserves();

        payee = s.cfmm; // deposit address is the CFMM

        // if first deposit deposit amounts desired
        if (reserve0 == 0 && reserve1 == 0) {
            return(amountsDesired, payee);
        }

        // revert if one side is zero
        if(reserve0 == 0 || reserve1 == 0) {
            revert ZeroReserves();
        }

        amounts = new uint256[](2);

        // calculate optimal amount1 to deposit if we deposit desired amount0
        uint256 optimalAmount1 = (amountsDesired[0] * reserve1) / reserve0;

        // if optimal amount1 <= desired proceed, else skip if block
        if (optimalAmount1 <= amountsDesired[1]) {
            // check optimal amount1 is greater than minimum deposit acceptable
            checkOptimalAmt(optimalAmount1, amountsMin[1]);
            (amounts[0], amounts[1]) = (amountsDesired[0], optimalAmount1);
            return(amounts, payee);
        }

        // calculate optimal amount0 to deposit if we deposit desired amount1
        uint256 optimalAmount0 = (amountsDesired[1] * reserve0) / reserve1;

        // if optimal amount0 <= desired proceed, else fail
        assert(optimalAmount0 <= amountsDesired[0]);

        // check that optimal amount0 is greater than minimum deposit acceptable
        checkOptimalAmt(optimalAmount0, amountsMin[0]);

        (amounts[0], amounts[1]) = (optimalAmount0, amountsDesired[1]);
    }

    /// @dev Check optimal deposit amount is not less than minimum acceptable deposit amount
    /// @param amountOptimal - optimal deposit amount
    /// @param amountMin - minimum deposit amount
    function checkOptimalAmt(uint256 amountOptimal, uint256 amountMin) internal virtual pure {
        if(amountOptimal < amountMin) {
            revert NotOptimalDeposit();
        }
    }

    /// @dev Get reserve token quantities in CFMM. UniswapV2 returns uint112, but we return array of uint128
    /// @param cfmm - address of CFMM we're reading reserve quantities from
    /// @return reserves - reserve token quantities in CFMM
    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
    }
}
