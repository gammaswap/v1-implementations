pragma solidity ^0.8.0;

import "../../../strategies/cpmm/CPMMShortStrategy.sol";

contract TestCPMMShortStrategy is CPMMShortStrategy {

    bytes32 public constant INIT_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    constructor() {
        GammaPoolStorage.init();
        CPMMStrategyStorage.init(msg.sender, INIT_CODE_HASH, 1, 2);
    }

    function testCheckOptimalAmt(uint256 amountOptimal, uint256 amountMin) public virtual pure returns(uint8){
        checkOptimalAmt(amountOptimal, amountMin);
        return 3;
    }

    function testGetReserves(address cfmm) public virtual view returns(uint256[] memory reserves){
        return getReserves(cfmm);
    }

    function testCalcDeposits(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) public virtual view returns(uint256[] memory amounts, address payee) {
        (amounts, payee) = calcDepositAmounts(GammaPoolStorage.store(), amountsDesired, amountsMin);
    }
}
