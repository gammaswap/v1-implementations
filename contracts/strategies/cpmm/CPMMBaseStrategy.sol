// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/external/ICPMM.sol";
import "../../libraries/Math.sol";
import "../../libraries/storage/CPMMStrategyStorage.sol";
import "../base/BaseStrategy.sol";

abstract contract CPMMBaseStrategy is BaseStrategy {

    function updateReserves(GammaPoolStorage.Store storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = ICPMM(store.cfmm).getReserves();
    }

    //Protocol specific functionality
    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        CPMMStrategyStorage.Store storage store = CPMMStrategyStorage.store();
        uint256 utilizationRate = (lpBorrowed * store.ONE) / (lpBalance + lpBorrowed);
        if(utilizationRate <= store.OPTIMAL_UTILIZATION_RATE) {
            uint256 variableRate = (utilizationRate * store.SLOPE1) / store.OPTIMAL_UTILIZATION_RATE;
            return (store.BASE_RATE + variableRate);
        } else {
            uint256 utilizationRateDiff = utilizationRate - store.OPTIMAL_UTILIZATION_RATE;
            uint256 variableRate = (utilizationRateDiff * store.SLOPE2) / (store.ONE - store.OPTIMAL_UTILIZATION_RATE);
            return(store.BASE_RATE + store.SLOPE1 + variableRate);
        }
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256) {
        return ICPMM(cfmm).mint(to);
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        GammaSwapLibrary.transfer(cfmm, cfmm, amount);
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = ICPMM(cfmm).burn(to);
    }

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }
}
