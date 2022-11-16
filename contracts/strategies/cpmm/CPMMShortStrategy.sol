// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../interfaces/external/ICPMM.sol";
import "../base/ShortStrategyERC4626.sol";
import "./CPMMBaseStrategy.sol";

contract CPMMShortStrategy is CPMMBaseStrategy, ShortStrategyERC4626 {

    error ZeroDeposits();
    error NotOptimalDeposit();

    constructor(uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _factor, uint256 _maxApy)
        CPMMBaseStrategy(_tradingFee1, _tradingFee2, _baseRate, _factor, _maxApy) {
    }

    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin)
            internal virtual override view returns (uint256[] memory amounts, address payee) {
        if(amountsDesired[0] == 0 || amountsDesired[1] == 0) {
            revert ZeroDeposits();
        }

        (uint256 reserve0, uint256 reserve1,) = ICPMM(store.cfmm).getReserves();

        payee = store.cfmm;
        if (reserve0 == 0 && reserve1 == 0) {
            return(amountsDesired, payee);
        }

        if(reserve0 == 0 || reserve1 == 0) {
            revert ZeroReserves();
        }

        amounts = new uint256[](2);

        uint256 optimalAmount1 = (amountsDesired[0] * reserve1) / reserve0;
        if (optimalAmount1 <= amountsDesired[1]) {
            checkOptimalAmt(optimalAmount1, amountsMin[1]);
            (amounts[0], amounts[1]) = (amountsDesired[0], optimalAmount1);
            return(amounts, payee);
        }

        uint256 optimalAmount0 = (amountsDesired[1] * reserve0) / reserve1;
        assert(optimalAmount0 <= amountsDesired[0]);
        checkOptimalAmt(optimalAmount0, amountsMin[0]);
        (amounts[0], amounts[1]) = (optimalAmount0, amountsDesired[1]);
    }

    function checkOptimalAmt(uint256 amountOptimal, uint256 amountMin) internal virtual pure {
        if(amountOptimal < amountMin) {
            revert NotOptimalDeposit();
        }
    }

    function getReserves(address cfmm) internal virtual override view returns(uint256[] memory reserves) {
        reserves = new uint256[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
    }
}
