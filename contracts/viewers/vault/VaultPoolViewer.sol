// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/base/PoolViewer.sol";
import "../../interfaces/vault/IVaultGammaPool.sol";
import "../../interfaces/vault/IVaultPoolViewer.sol";

/// @title Implementation of Viewer Contract for Vault GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used make complex view function calls from GammaPool's storage data (e.g. updated loan and pool debt)
contract VaultPoolViewer is PoolViewer, IVaultPoolViewer {

    /// @inheritdoc PoolViewer
    function _getUpdatedLoans(address pool, IGammaPool.LoanData[] memory _loans) internal virtual override view returns(IGammaPool.LoanData[] memory) {
        address[] memory _tokens = IGammaPool(pool).tokens();
        (string[] memory _symbols, string[] memory _names, uint8[] memory _decimals) = getTokensMetaData(_tokens);
        IGammaPool.RateData memory data = _getLastFeeIndex(pool);
        uint256 _size = _loans.length;
        IGammaPool.LoanData memory _loan;
        for(uint256 i = 0; i < _size;) {
            _loan = _loans[i];
            if(_loan.id == 0) {
                break;
            }
            _loan.tokens = _tokens;
            _loan.symbols = _symbols;
            _loan.names = _names;
            _loan.decimals = _decimals;
            address refAddr = address(0);
            if(_loan.refType == 3) {
                refAddr = _loan.refAddr;
            } else {
                _loan.liquidity = _updateLiquidity(_loan.liquidity, _loan.rateIndex, data.accFeeIndex);
            }
            _loan.collateral = _collateral(pool, _loan.tokenId, _loan.tokensHeld, refAddr);
            _loan.shortStrategy = data.shortStrategy;
            _loan.paramsStore = data.paramsStore;
            _loan.ltvThreshold = data.ltvThreshold;
            _loan.liquidationFee = data.liquidationFee;
            _loan.canLiquidate = _canLiquidate(_loan.liquidity, _loan.collateral, _loan.ltvThreshold);
            unchecked {
                ++i;
            }
        }
        return _loans;
    }

    /// @inheritdoc IPoolViewer
    function loan(address pool, uint256 tokenId) external virtual override view returns(IGammaPool.LoanData memory _loanData) {
        _loanData = IGammaPool(pool).getLoanData(tokenId);
        if(_loanData.id == 0) {
            return _loanData;
        }
        _loanData.accFeeIndex = _getLoanLastFeeIndex(_loanData);
        address refAddr = address(0);
        if(_loanData.refType == 3) {
            refAddr = _loanData.refAddr;
        } else {
            _loanData.liquidity = _updateLiquidity(_loanData.liquidity, _loanData.rateIndex, _loanData.accFeeIndex);
        }
        _loanData.collateral = _collateral(pool, tokenId, _loanData.tokensHeld, refAddr);
        _loanData.canLiquidate = _canLiquidate(_loanData.liquidity, _loanData.collateral, _loanData.ltvThreshold);
        (_loanData.symbols, _loanData.names, _loanData.decimals) = getTokensMetaData(_loanData.tokens);
        return _loanData;
    }

    /// @inheritdoc IPoolViewer
    function canLiquidate(address pool, uint256 tokenId) external virtual override view returns(bool) {
        IGammaPool.LoanData memory _loanData = IGammaPool(pool).getLoanData(tokenId);
        if(_loanData.liquidity == 0) {
            return false;
        }
        address refAddr = address(0);
        if(_loanData.refType == 3) {
            refAddr = _loanData.refAddr;
        } else {
            _loanData.liquidity = _updateLiquidity(_loanData.liquidity, _loanData.rateIndex, _loanData.accFeeIndex);
        }
        uint256 collateral = _collateral(pool, tokenId, _loanData.tokensHeld, refAddr);
        return _canLiquidate(_loanData.liquidity, collateral, _loanData.ltvThreshold);
    }

    /// @inheritdoc PoolViewer
    function _getLastFeeIndex(address pool) internal virtual override view returns(IGammaPool.RateData memory data) {
        IGammaPool.PoolData memory params = IGammaPool(pool).getPoolData();

        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(pool).getLatestCFMMBalances();
        if(lastCFMMTotalSupply > 0) {
            uint256 maxCFMMFeeLeverage;
            uint256 spread;
            (data.borrowRate,data.utilizationRate,maxCFMMFeeLeverage,spread) = AbstractRateModel(params.shortStrategy)
                .calcBorrowRate(params.LP_INVARIANT, params.BORROWED_INVARIANT, params.paramsStore, pool);

            (data.lastFeeIndex,data.lastCFMMFeeIndex) = IShortStrategy(params.shortStrategy)
                .getLastFees(data.borrowRate, params.BORROWED_INVARIANT, lastCFMMInvariant, lastCFMMTotalSupply,
                params.lastCFMMInvariant, params.lastCFMMTotalSupply, params.LAST_BLOCK_NUMBER, params.lastCFMMFeeIndex,
                maxCFMMFeeLeverage, spread);

            data.supplyRate = data.borrowRate * data.utilizationRate / 1e18;

            (data.LP_INVARIANT,) = IVaultGammaPool(pool).getReservedBalances();
            data.LP_INVARIANT = GSMath.min(params.BORROWED_INVARIANT, data.LP_INVARIANT);
            unchecked {
                data.BORROWED_INVARIANT = uint256(params.BORROWED_INVARIANT) - data.LP_INVARIANT;
            }
            (,,data.BORROWED_INVARIANT) = IShortStrategy(params.shortStrategy).getLatestBalances(data.lastFeeIndex,
                data.BORROWED_INVARIANT, params.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply);

            data.BORROWED_INVARIANT = data.BORROWED_INVARIANT + data.LP_INVARIANT;
            data.LP_INVARIANT = uint128(params.LP_TOKEN_BALANCE * lastCFMMInvariant / lastCFMMTotalSupply);

            data.utilizationRate = _calcUtilizationRate(data.LP_INVARIANT, data.BORROWED_INVARIANT);
            data.emaUtilRate = uint40(IShortStrategy(params.shortStrategy).calcUtilRateEma(data.utilizationRate,
                params.emaUtilRate, GSMath.max(block.number - params.LAST_BLOCK_NUMBER, params.emaMultiplier)));
        } else {
            data.lastFeeIndex = 1e18;
        }

        data.origFee = params.origFee;
        data.feeDivisor = params.feeDivisor;
        data.minUtilRate1 = params.minUtilRate1;
        data.minUtilRate2 = params.minUtilRate2;
        data.ltvThreshold = params.ltvThreshold;
        data.liquidationFee = params.liquidationFee;
        data.shortStrategy = params.shortStrategy;
        data.paramsStore = params.paramsStore;

        data.accFeeIndex = params.accFeeIndex * data.lastFeeIndex / 1e18;
        data.lastBlockNumber = params.LAST_BLOCK_NUMBER;
        data.currBlockNumber = block.number;
    }

    /// @inheritdoc IPoolViewer
    function getLatestPoolData(address pool) public virtual override view returns(IGammaPool.PoolData memory data) {
        data = getPoolData(pool);
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (data.CFMM_RESERVES, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(pool).getLatestCFMMBalances();
        if(lastCFMMTotalSupply == 0) {
            return data;
        }

        uint256 lastCFMMFeeIndex; // holding maxCFMMFeeLeverage temporarily
        uint256 borrowedInvariant; // holding spread temporarily
        (data.borrowRate, data.utilizationRate, lastCFMMFeeIndex, borrowedInvariant) =
            AbstractRateModel(data.shortStrategy).calcBorrowRate(data.LP_INVARIANT, data.BORROWED_INVARIANT,
                data.paramsStore, pool);

        (data.lastFeeIndex,lastCFMMFeeIndex) = IShortStrategy(data.shortStrategy)
        .getLastFees(data.borrowRate, data.BORROWED_INVARIANT, lastCFMMInvariant, lastCFMMTotalSupply,
            data.lastCFMMInvariant, data.lastCFMMTotalSupply, data.LAST_BLOCK_NUMBER, data.lastCFMMFeeIndex,
            lastCFMMFeeIndex, borrowedInvariant);

        data.supplyRate = data.borrowRate * data.utilizationRate / 1e18;

        data.lastCFMMFeeIndex = uint64(lastCFMMFeeIndex);

        (lastCFMMFeeIndex,) = IVaultGammaPool(pool).getReservedBalances();
        lastCFMMFeeIndex = GSMath.min(data.BORROWED_INVARIANT, lastCFMMFeeIndex);
        unchecked {
            borrowedInvariant = data.BORROWED_INVARIANT - lastCFMMFeeIndex;
        }
        (,data.LP_TOKEN_BORROWED_PLUS_INTEREST, borrowedInvariant) = IShortStrategy(data.shortStrategy)
        .getLatestBalances(data.lastFeeIndex, borrowedInvariant, data.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply);

        data.LP_TOKEN_BORROWED_PLUS_INTEREST += lastCFMMFeeIndex * lastCFMMTotalSupply / lastCFMMInvariant;

        data.BORROWED_INVARIANT = uint128(borrowedInvariant + lastCFMMFeeIndex);
        data.LP_INVARIANT = uint128(data.LP_TOKEN_BALANCE * lastCFMMInvariant / lastCFMMTotalSupply);
        data.accFeeIndex = uint80(data.accFeeIndex * data.lastFeeIndex / 1e18);

        data.utilizationRate = _calcUtilizationRate(data.LP_INVARIANT, data.BORROWED_INVARIANT);
        data.emaUtilRate = uint40(IShortStrategy(data.shortStrategy).calcUtilRateEma(data.utilizationRate, data.emaUtilRate,
            GSMath.max(block.number - data.LAST_BLOCK_NUMBER, data.emaMultiplier)));

        data.lastPrice = IGammaPool(pool).getLastCFMMPrice();
        data.lastCFMMInvariant = uint128(lastCFMMInvariant);
        data.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    /// @dev Returns vault pool storage data updated to their latest values
    /// @notice Difference with getVaultPoolData() is this struct is what PoolData would return if an update of the GammaPool were to occur at the current block
    /// @param pool - address of pool to get pool data for
    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getLatestVaultPoolData(address pool) public virtual override view returns(IVaultPoolViewer.VaultPoolData memory data) {
        (data.reservedBorrowedInvariant, data.reservedLPTokens) = IVaultGammaPool(pool).getReservedBalances();
        data.poolData = getLatestPoolData(pool);
    }

    /// @dev Return vault pool storage data
    /// @param pool - address of pool to get pool data for
    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getVaultPoolData(address pool) public virtual override view returns(IVaultPoolViewer.VaultPoolData memory data) {
        (data.reservedBorrowedInvariant, data.reservedLPTokens) = IVaultGammaPool(pool).getReservedBalances();
        data.poolData = IGammaPool(pool).getPoolData();
    }
}