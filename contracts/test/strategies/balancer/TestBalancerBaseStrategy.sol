// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/balancer/BalancerBaseStrategy.sol";

contract TestBalancerBaseStrategy is BalancerBaseStrategy {

    using LibStorage for LibStorage.Storage;

    event DepositToCFMM(address cfmm, address to, uint256 liquidity);
    event WithdrawFromCFMM(address cfmm, address to, uint256[] amounts);

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        BalancerBaseStrategy(2252571, _baseRate, _factor, _maxApy) {
    }

    function initialize(address cfmm, address[] calldata tokens, uint8[] calldata decimals) external virtual {
        s.initialize(msg.sender, cfmm, tokens, decimals);
    }

    function getCFMM() public virtual view returns(address) {
        return s.cfmm;
    }

    function getCFMMReserves() public virtual view returns(uint128[] memory) {
        return s.CFMM_RESERVES;
    }

    function testUpdateReserves() public virtual {
        updateReserves(s.cfmm);
    }

    function testDepositToCFMM(address cfmm, uint256[] memory amounts, address to) public virtual {
        uint256 liquidity = depositToCFMM(cfmm, to, amounts);
        emit DepositToCFMM(cfmm, to, liquidity);
    }

    function testWithdrawFromCFMM(address cfmm, uint256 amount, address to) public virtual {
        uint256[] memory amounts = withdrawFromCFMM(cfmm, to, amount);
        emit WithdrawFromCFMM(cfmm, to, amounts);
    }

    function testCalcInvariant(address cfmm, uint128[] memory amounts) public virtual view returns(uint256) {
        return calcInvariant(cfmm, amounts);
    }
}
