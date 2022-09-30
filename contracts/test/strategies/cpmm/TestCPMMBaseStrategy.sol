// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../../strategies/cpmm/CPMMBaseStrategy.sol";
import "../../../libraries/storage/strategies/CPMMStrategyStorage.sol";

contract TestCPMMBaseStrategy is CPMMBaseStrategy {
    event DepositToCFMM(address cfmm, address to, uint256 liquidity);
    event WithdrawFromCFMM(address cfmm, address to, uint256[] amounts);

    bytes32 public constant INIT_CODE_HASH = 0x27285ab59f8ba133307fa420eb84d62bb43c162ff701cc3df8b9e638194fa370;

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
    /*
    function updateReserves(GammaPoolStorage.Store storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = ICPMM(store.cfmm).getReserves();
    }
    */
}
