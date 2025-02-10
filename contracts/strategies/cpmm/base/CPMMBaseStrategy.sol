// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gammaswap/v1-core/contracts/rates/LinearKinkedRateModel.sol";
import "@gammaswap/v1-core/contracts/strategies/base/BaseStrategy.sol";
import "../../../interfaces/external/cpmm/ICPMM.sol";

/// @title Base Strategy abstract contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for Constant Product Market Maker
/// @dev This implementation was specifically designed to work with UniswapV2. Inherits Rate Model
abstract contract CPMMBaseStrategy is BaseStrategy, LinearKinkedRateModel {

    using LibStorage for LibStorage.Storage;

    error MaxTotalApy();

    /// @dev Number of blocks network will issue within a ear. Currently expected
    uint256 immutable public BLOCKS_PER_YEAR; // 2628000 blocks per year in ETH mainnet (12 seconds per block)

    /// @dev Default max total APY the GammaPool will charge liquidity borrowers (e.g. 1,000%).
    uint256 immutable public MAX_TOTAL_APY;

    /// @dev Key for overriding default max total APY
    bytes32 internal constant MAX_TOTAL_APY_KEY = keccak256("MAX_TOTAL_APY");

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_)
        LinearKinkedRateModel(baseRate_, optimalUtilRate_, slope1_, slope2_) {
        // maxTotalApy (CFMM Fees + GammaSwap interest rate) can't be >= maxApy (max GammaSwap interest rate)
        if(maxTotalApy_ == 0 || maxTotalApy_ < baseRate_ + slope1_ + slope2_) revert MaxTotalApy();

        MAX_TOTAL_APY = maxTotalApy_;
        BLOCKS_PER_YEAR = blocksPerYear_;
    }

    /// @dev If set to 0 use default max total APY
    /// @dev See {BaseStrategy-maxTotalApy}.
    function maxTotalApy() internal virtual override view returns(uint256) {
        uint256 _maxTotalApy = s.getUint256(uint256(MAX_TOTAL_APY_KEY));
        if(_maxTotalApy == 0) {
            return MAX_TOTAL_APY;
        }
        return _maxTotalApy;
    }

    /// @dev See {BaseStrategy-blocksPerYear}.
    function blocksPerYear() internal virtual override view returns(uint256) {
        return BLOCKS_PER_YEAR;
    }

    /// @dev See {BaseStrategy-syncCFMM}.
    function syncCFMM(address cfmm) internal virtual override {
        ICPMM(cfmm).sync();
    }

    /// @dev See {BaseStrategy-getReserves}.
    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
    }

    /// @dev See {BaseStrategy-getReserves}.
    function getLPReserves(address cfmm, bool isLatest) internal virtual override view returns(uint128[] memory reserves) {
        if(isLatest) {
            reserves = new uint128[](2);
            (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
        } else {
            reserves = s.CFMM_RESERVES;
        }
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
        return GSMath.sqrt(uint256(amounts[0]) * amounts[1]);
    }
}
