// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/cpmm/CPMMBaseStrategy.sol";

contract TestCPMMBaseStrategy is CPMMBaseStrategy {
    event DepositToCFMM(address cfmm, address to, uint256 liquidity);
    event WithdrawFromCFMM(address cfmm, address to, uint256[] amounts);

    constructor(uint256 _baseRate, uint256 _factor, uint256 _maxApy)
        CPMMBaseStrategy(_baseRate, _factor, _maxApy) {
    }

    function initialize(address cfmm, address[] calldata tokens) external virtual {
        GammaPoolStorage.init(cfmm, tokens);
    }

    function getCFMM() public virtual view returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    function getCFMMReserves() public virtual view returns(uint256[] memory) {
        return GammaPoolStorage.store().CFMM_RESERVES;
    }

    function testUpdateReserves() public virtual {
        updateReserves(GammaPoolStorage.store());
    }

    function testDepositToCFMM(address cfmm, uint256[] memory amounts, address to) public virtual {
        uint256 liquidity = depositToCFMM(cfmm, amounts, to);
        emit DepositToCFMM(cfmm, to, liquidity);
    }

    function testWithdrawFromCFMM(address cfmm, uint256 amount, address to) public virtual {
        uint256[] memory amounts = withdrawFromCFMM(cfmm, to, amount);
        emit WithdrawFromCFMM(cfmm, to, amounts);
    }

    function testCalcInvariant(address cfmm, uint256[] memory amounts) public virtual view returns(uint256) {
        return calcInvariant(cfmm, amounts);
    }
}
