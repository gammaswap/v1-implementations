// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../../strategies/balancer/BalancerShortStrategy.sol";

contract TestBalancerShortStrategy is BalancerShortStrategy {

    using LibStorage for LibStorage.Storage;

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy, address _vault)
        BalancerShortStrategy(_baseRate, _factor, _maxApy, _vault) {
    }

    function initialize(address cfmm, address[] calldata tokens, uint8[] calldata decimals) external virtual {
        s.initialize(msg.sender, cfmm, tokens, decimals);
    }

    function testCalcDeposits(uint256[] calldata amountsDesired, uint256[] calldata amountsMin) public virtual view returns(uint256[] memory amounts, address payee) {
        (amounts, payee) = calcDepositAmounts(amountsDesired, amountsMin);
    }

    function testCheckOptimalAmt(uint256 amountOptimal, uint256 amountMin) public virtual pure returns(uint8){
        checkOptimalAmt(amountOptimal, amountMin);
        return 3;
    }

    function testGetReserves(address cfmm) public virtual view returns(uint128[] memory reserves){
        return getReserves(cfmm);
    }
}
