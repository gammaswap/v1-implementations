// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/external/ICPMM.sol";
import "../../libraries/Math.sol";
import "../../rates/LinearKinkedRateModel.sol";
import "../../interfaces/strategies/ICPMMStrategy.sol";
import "../base/BaseStrategy.sol";

abstract contract CPMMBaseStrategy is ICPMMStrategy, BaseStrategy, LinearKinkedRateModel {

    error ZeroReserves();

    uint16 immutable public override tradingFee1;
    uint16 immutable public override tradingFee2;

    constructor(uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _optimalUtilRate, uint256 _slope1, uint256 _slope2) LinearKinkedRateModel(_baseRate, _optimalUtilRate, _slope1, _slope2){
        tradingFee1 = _tradingFee1;
        tradingFee2 = _tradingFee2;
    }

    function updateReserves(GammaPoolStorage.Store storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = ICPMM(store.cfmm).getReserves();
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256) {
        return ICPMM(cfmm).mint(to);
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        GammaSwapLibrary.safeTransfer(IERC20(cfmm), cfmm, amount);
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = ICPMM(cfmm).burn(to);
    }

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }
}
