// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/ShortStrategySync.sol";
import "../../interfaces/external/cpmm/ICPMM.sol";
import "./CPMMBaseStrategy.sol";

/// @title Short Strategy concrete implementation contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Sets up variables used by ShortStrategy and defines internal functions specific to CPMM implementation
/// @dev This implementation was specifically designed to work with UniswapV2
contract CPMMShortStrategy is CPMMBaseStrategy, ShortStrategySync {

    error ZeroDeposits();
    error NotOptimalDeposit();
    error ZeroReserves();

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `baseRate`, `factor`, and `maxApy`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint64 baseRate_, uint80 factor_, uint80 maxApy_)
        CPMMBaseStrategy(maxTotalApy_, blocksPerYear_, baseRate_, factor_, maxApy_) {
    }

    /// @dev See {IShortStrategy-_getLatestCFMMReserves}.
    function _getLatestCFMMReserves(bytes memory _cfmm) public virtual override view returns(uint128[] memory reserves) {
        address cfmm_ = abi.decode(_cfmm, (address));
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm_).getReserves(); // return uint256 to avoid casting
    }

    /// @dev See {IShortStrategy-_getLatestCFMMInvariant}.
    function _getLatestCFMMInvariant(bytes memory _cfmm) public virtual override view returns(uint256 cfmmInvariant) {
        uint128[] memory reserves = _getLatestCFMMReserves(_cfmm);
        cfmmInvariant = calcInvariant(address(0), reserves);
    }

    /// @dev See {IShortStrategy-calcDepositAmounts}.
    function calcDepositAmounts(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) internal virtual
        override view returns (uint256[] memory amounts, address payee) {

        if(amountsDesired[0] == 0 || amountsDesired[1] == 0) revert ZeroDeposits(); // revert if not depositing anything

        (uint256 reserve0, uint256 reserve1,) = ICPMM(s.cfmm).getReserves();

        payee = s.cfmm; // deposit address is the CFMM

        // if first deposit deposit amounts desired
        if (reserve0 == 0 && reserve1 == 0) {
            return(amountsDesired, payee);
        }

        // revert if one side is zero
        if(reserve0 == 0 || reserve1 == 0) revert ZeroReserves();

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
        if(amountOptimal < amountMin) revert NotOptimalDeposit();
    }
}
