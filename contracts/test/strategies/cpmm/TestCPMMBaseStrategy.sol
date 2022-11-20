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
        s.cfmm = cfmm;
        s.tokens = tokens;
        s.factory = msg.sender;
        s.TOKEN_BALANCE = new uint256[](tokens.length);
        s.CFMM_RESERVES = new uint256[](tokens.length);

        s.accFeeIndex = 10**18;
        s.lastFeeIndex = 10**18;
        s.lastCFMMFeeIndex = 10**18;
        s.LAST_BLOCK_NUMBER = block.number;
        s.nextId = 1;
        s.unlocked = 1;
        s.ONE = 10**18;
    }

    function getCFMM() public virtual view returns(address) {
        return s.cfmm;
    }

    function getCFMMReserves() public virtual view returns(uint256[] memory) {
        return s.CFMM_RESERVES;
    }

    function testUpdateReserves() public virtual {
        updateReserves();
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
