// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../strategies/base/BaseStrategy.sol";
import "../interfaces/external/ICPMM.sol";
import "../libraries/Math.sol";

contract TestBaseStrategy is BaseStrategy {
    uint256 public invariant;
    uint256 public borrowRate = 10**18;

    constructor() {
        GammaPoolStorage.init();
    }

    function getParameters() public virtual view returns(address factory, address cfmm, address[] memory tokens, uint24 protocolId, address protocol) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        factory = store.factory;
        cfmm = store.cfmm;
        tokens = store.tokens;
        protocolId = store.protocolId;
        protocol = store.protocol;
    }

    function setBorrowRate(uint256 _borrowRate) public virtual {
        borrowRate = _borrowRate;
    }

    function setLastBlockNumber(uint256 lastBlockNumber) public virtual {
        GammaPoolStorage.store().LAST_BLOCK_NUMBER = lastBlockNumber;
    }

    function getLastBlockNumber() public virtual view returns(uint256) {
        return GammaPoolStorage.store().LAST_BLOCK_NUMBER;
    }

    function setCFMMIndex(uint256 cfmmIndex) public virtual {
        GammaPoolStorage.store().lastCFMMFeeIndex = cfmmIndex;
    }

    function getCFMMIndex() public virtual view returns(uint256){
        return GammaPoolStorage.store().lastCFMMFeeIndex;
    }

    function testUpdateTWAP() internal virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
    }

    function testUpdateIndex() internal virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
    }

    function testUpdateLoan() internal {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
    }

    function testUpdateCFMMIndex() public virtual {
        updateCFMMIndex(GammaPoolStorage.store());
    }

    function testUpdateFeeIndex() public virtual {
        updateFeeIndex(GammaPoolStorage.store());
    }

    function getLastFeeIndex() public virtual view returns(uint256){
        return GammaPoolStorage.store().lastFeeIndex;
    }

    function getCFMMData() public virtual view returns(uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        lastCFMMFeeIndex = store.lastCFMMFeeIndex;
        lastCFMMInvariant = store.lastCFMMInvariant;
        lastCFMMTotalSupply = store.lastCFMMTotalSupply;
    }

    function testMint(address account, uint256 amount) public virtual {
        _mint(GammaPoolStorage.store(), account, amount);
    }

    function testBurn(address account, uint256 amount) public virtual {
        _burn(GammaPoolStorage.store(), account, amount);
    }

    function totalSupply() public virtual view returns(uint256) {
        return GammaPoolStorage.store().totalSupply;
    }

    function balanceOf(address account) public virtual view returns(uint256) {
        return GammaPoolStorage.store().balanceOf[account];
    }

    function testMintToDevs() internal virtual {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
    }

    // Need to set this
    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        return borrowRate;
    }

    function getReserves() public virtual view returns(uint256[] memory) {
        return GammaPoolStorage.store().CFMM_RESERVES;
    }

    function testUpdateReserves() public virtual {
        updateReserves(GammaPoolStorage.store());
    }

    // Need to set this
    function updateReserves(GammaPoolStorage.Store storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = ICPMM(store.cfmm).getReserves();
    }

    function setInvariant(uint256 _invariant) public virtual {
        invariant = _invariant;
    }

    // Need to set this
    function calcInvariant(address cfmm, uint256[] memory amounts) internal virtual override view returns(uint256) {
        return invariant;
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256 liquidity) { return 0; }

    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint256[] memory amounts) { return amounts; }
}
