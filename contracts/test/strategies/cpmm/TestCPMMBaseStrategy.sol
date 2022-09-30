// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../../strategies/cpmm/CPMMBaseStrategy.sol";
import "../../../libraries/storage/strategies/CPMMStrategyStorage.sol";

contract TestCPMMBaseStrategy is CPMMBaseStrategy {
    event DepositToCFMM(address cfmm, address to, uint256 liquidity);
    event WithdrawFromCFMM(address cfmm, address to, uint256[] amounts);

    bytes32 public constant INIT_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    constructor() {
        GammaPoolStorage.init();
        CPMMStrategyStorage.init(msg.sender, INIT_CODE_HASH, 1, 2);
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
