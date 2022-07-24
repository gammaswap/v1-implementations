// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../base/ShortStrategy.sol";
import "./CPMMBaseStrategy.sol";

contract CPMMShortStrategy is CPMMBaseStrategy, ShortStrategy {

    constructor(address factory, address protocolFactory, uint24 protocol, bytes32 initCodeHash){
        CPMMStrategyStorage.init(factory, protocolFactory, protocol, initCodeHash);
    }

    function calcDepositAmounts(GammaPoolStorage.Store storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin)
            internal virtual override returns (uint256[] memory amounts, address payee) {
        require(amountsDesired[0] > 0 && amountsDesired[1] > 0, '0 amount');

        (uint256 reserve0, uint256 reserve1) = (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1]);
        require(reserve0 > 0 && reserve1 > 0, '0 reserve');

        payee = store.cfmm;
        if (reserve0 == 0 && reserve1 == 0) {
            return(amountsDesired, payee);
        }

        amounts = new uint256[](2);

        uint256 optimalAmount1 = (amountsDesired[0] * reserve1) / reserve0;
        if (optimalAmount1 <= amountsDesired[1]) {
            checkOptimalAmt(optimalAmount1, amountsMin[1]);
            (amounts[0], amounts[1]) = (amountsDesired[0], optimalAmount1);
            return(amounts, payee);
        }

        uint256 optimalAmount0 = (amountsDesired[1] * reserve0) / reserve1;
        assert(optimalAmount0 <= amountsDesired[0]);
        checkOptimalAmt(optimalAmount0, amountsMin[0]);
        (amounts[0], amounts[1]) = (optimalAmount0, amountsDesired[1]);
    }

    function checkOptimalAmt(uint256 amountOptimal, uint256 amountMin) internal virtual pure {
        require(amountOptimal >= amountMin, '< minAmt');
    }
}