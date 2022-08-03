// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/external/ICPMM.sol";
import "../../libraries/Math.sol";
import "../../libraries/storage/strategies/CPMMStrategyStorage.sol";
import "../../rates/LinearKinkedRateModel.sol";
import "../../interfaces/strategies/ICPMMStrategy.sol";
import "../base/BaseStrategy.sol";

abstract contract CPMMBaseStrategy is ICPMMStrategy, BaseStrategy, LinearKinkedRateModel {
    constructor(bytes memory sData, bytes memory rData) {
        CPMMStrategyStorage.Store memory sParams = abi.decode(sData, (CPMMStrategyStorage.Store));
        CPMMStrategyStorage.init(sParams.factory, sParams.initCodeHash, sParams.tradingFee1, sParams.tradingFee2);

        LinearKinkedRateStorage.Store memory rParams = abi.decode(rData, (LinearKinkedRateStorage.Store));
        LinearKinkedRateStorage.init(rParams.baseRate, rParams.optimalUtilRate, rParams.slope1, rParams.slope2);
    }

    function updateReserves(GammaPoolStorage.Store storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = ICPMM(store.cfmm).getReserves();
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256) {
        return ICPMM(cfmm).mint(to);
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        GammaSwapLibrary.safeTransfer(cfmm, cfmm, amount);
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = ICPMM(cfmm).burn(to);
    }

    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }

    //this is the factory of the protocol (Not all protocols have a factory)
    function factory() external virtual override view returns(address) {
        return CPMMStrategyStorage.store().factory;
    }

    function initCodeHash() external virtual override view returns(bytes32) {
        return CPMMStrategyStorage.store().initCodeHash;
    }

    function tradingFee1() external virtual override view returns(uint16) {
        return CPMMStrategyStorage.store().tradingFee1;
    }

    function tradingFee2() external virtual override view returns(uint16) {
        return CPMMStrategyStorage.store().tradingFee2;
    }
}
