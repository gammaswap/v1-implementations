// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../strategies/deltaswap/DSV2ShortStrategy.sol";

contract TestDSV2ShortStrategy is DSV2ShortStrategy {

    using LibStorage for LibStorage.Storage;

    constructor(uint64 _baseRate, uint64 _optimalUtilRate, uint64 _slope1, uint64 _slope2)
        DSV2ShortStrategy(1e19, 2252571, _baseRate, _optimalUtilRate, _slope1, _slope2) {
    }

    function initialize(address cfmm, address[] calldata tokens, uint8[] calldata decimals) external virtual {
        s.initialize(msg.sender, cfmm, 1, tokens, decimals, 1e3);
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
