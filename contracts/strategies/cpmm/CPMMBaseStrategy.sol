// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/external/ICPMM.sol";
import "../../libraries/Math.sol";
import "../../rates/LogDerivativeRateModel.sol";
import "../base/BaseStrategy.sol";

abstract contract CPMMBaseStrategy is BaseStrategy, LogDerivativeRateModel {

    uint256 immutable public BLOCKS_PER_YEAR;//2252571 year block count in ETH mainnet

    constructor(uint256 _blocksPerYear, uint64 _baseRate, uint80 _factor, uint80 _maxApy) LogDerivativeRateModel(_baseRate, _factor, _maxApy) {
        BLOCKS_PER_YEAR = _blocksPerYear;
    }

    function blocksPerYear() internal virtual override view returns(uint256) {
        return BLOCKS_PER_YEAR;
    }

    function updateReserves(address cfmm) internal virtual override {
        (s.CFMM_RESERVES[0], s.CFMM_RESERVES[1],) = ICPMM(cfmm).getReserves();
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256) {
        return ICPMM(cfmm).mint(to);
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        GammaSwapLibrary.safeTransfer(IERC20(cfmm), cfmm, amount);
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = ICPMM(cfmm).burn(to);
    }

    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(uint256(amounts[0]) * amounts[1]);
    }
}
