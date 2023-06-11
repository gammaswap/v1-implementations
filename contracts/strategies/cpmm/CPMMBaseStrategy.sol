// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/rates/LogDerivativeRateModel.sol";
import "@gammaswap/v1-core/contracts/strategies/base/BaseStrategy.sol";
import "../../interfaces/external/cpmm/ICPMM.sol";

/// @title Base Strategy abstract contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for Constant Product Market Maker
/// @dev This implementation was specifically designed to work with UniswapV2. Inherits Rate Model
abstract contract CPMMBaseStrategy is BaseStrategy, LogDerivativeRateModel {

    error MaxTotalApy();

    /// @dev Number of blocks network will issue within a ear. Currently expected
    uint256 immutable public BLOCKS_PER_YEAR; // 2628000 blocks per year in ETH mainnet (12 seconds per block)

    /// @dev Max total annual APY the GammaPool will charge liquidity borrowers (e.g. 1,000%).
    uint256 immutable public MAX_TOTAL_APY;

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `baseRate`, `factor`, and `maxApy`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint64 baseRate_, uint80 factor_, uint80 maxApy_)
        LogDerivativeRateModel(baseRate_, factor_, maxApy_) {
        // maxTotalApy (CFMM Fees + GammaSwap interest rate) can't be >= maxApy (max GammaSwap interest rate)
        if(maxTotalApy_ < maxApy_) revert MaxTotalApy();

        MAX_TOTAL_APY = maxTotalApy_;
        BLOCKS_PER_YEAR = blocksPerYear_;
    }

    /// @dev See {BaseStrategy-maxTotalApy}.
    function maxTotalApy() internal virtual override view returns(uint256) {
        return MAX_TOTAL_APY;
    }

    /// @dev See {BaseStrategy-blocksPerYear}.
    function blocksPerYear() internal virtual override view returns(uint256) {
        return BLOCKS_PER_YEAR;
    }

    /// @dev See {BaseStrategy-getReserves}.
    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
    }

    /// @dev See {BaseStrategy-depositToCFMM}.
    function depositToCFMM(address cfmm, address to, uint256[] memory) internal virtual override returns(uint256) {
        return ICPMM(cfmm).mint(to);
    }

    /// @dev See {BaseStrategy-withdrawFromCFMM}.
    function withdrawFromCFMM(address cfmm, address to, uint256 lpTokens) internal virtual override
        returns(uint256[] memory amounts) {
        GammaSwapLibrary.safeTransfer(cfmm, cfmm, lpTokens);
        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = ICPMM(cfmm).burn(to);
    }

    /// @dev See {BaseStrategy-calcInvariant}.
    function calcInvariant(address, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(uint256(amounts[0]) * amounts[1]);
    }
}
