// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "../../pools/CPMMGammaPool.sol";

contract TestCPMMGammaPool is CPMMGammaPool {
    uint256 public _loanLiquidity;
    uint256 public _sqrtPx;
    uint128 public _reserve0;
    uint128 public _reserve1;

    constructor(uint16 _protocolId, address _factory, address _borrowStrategy, address _repayStrategy, address _shortStrategy, address _liquidationStrategy, address _batchLiquidationStrategy, address _viewer, address _cfmmFactory, bytes32 _cfmmInitCodeHash)
        CPMMGammaPool(_protocolId, _factory, _borrowStrategy, _repayStrategy, _shortStrategy, _liquidationStrategy, _batchLiquidationStrategy, _viewer, address(0), address(0), _cfmmFactory, _cfmmInitCodeHash) {
        s.decimals = new uint8[](2);
        s.decimals[0] = 18;
        s.decimals[1] = 18;
    }

    function setData(uint256 mLoanLiquidity, uint256 mSqrtPx, uint256 mReserve0, uint256 mReserve1) external virtual {
        _loanLiquidity = mLoanLiquidity;
        _sqrtPx = mSqrtPx;
        _reserve0 = uint128(mReserve0);
        _reserve1 = uint128(mReserve1);
    }

    function _getLatestCFMMReserves() internal virtual override view returns(uint128[] memory cfmmReserves) {
        cfmmReserves = new uint128[](2);
        cfmmReserves[0] = _reserve0;
        cfmmReserves[1] = _reserve1;
    }
}
