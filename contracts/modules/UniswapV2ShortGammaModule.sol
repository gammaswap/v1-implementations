pragma solidity ^0.8.0;

import "./ShortGammaModule.sol";
import "./UniswapV2BaseModule.sol";

contract UniswapV2ShortGammaModule is UniswapV2BaseModule, ShortGammaModule {

    constructor(address factory, address protocolFactory, uint24 protocol, bytes32 initCodeHash){
        UniswapV2Storage.init(factory, protocolFactory, protocol, initCodeHash);//bytes32(0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f));//UniswapV2
        //hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
        // bytes32(0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303));//SushiSwap
    }

    function calcDepositAmounts(GammaPoolStorage.GammaPoolStore storage store, uint256[] calldata amountsDesired, uint256[] calldata amountsMin)
            internal virtual override returns (uint256[] memory amounts, address payee) {
        require(amountsDesired[0] > 0 && amountsDesired[1] > 0, '0 amount');

        (uint256 reserve0, uint256 reserve1) = (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1]);
        require(reserve0 > 0 && reserve1 > 0, '0 reserve');

        payee = store.cfmm;
        if (reserve0 == 0 && reserve1 == 0) {
            return(amountsDesired, payee);
        }

        amounts = new uint256[](2);

        uint optimalAmount1 = (amountsDesired[0] * reserve1) / reserve0;
        if (optimalAmount1 <= amountsDesired[1]) {
            checkOptimalAmt(optimalAmount1, amountsMin[1]);
            (amounts[0], amounts[1]) = (amountsDesired[0], optimalAmount1);
            return(amounts, payee);
        }

        uint optimalAmount0 = (amountsDesired[1] * reserve0) / reserve1;
        assert(optimalAmount0 <= amountsDesired[0]);
        checkOptimalAmt(optimalAmount0, amountsMin[0]);
        (amounts[0], amounts[1]) = (optimalAmount0, amountsDesired[1]);
    }

    function checkOptimalAmt(uint256 amountOptimal, uint256 amountMin) internal virtual pure {
        require(amountOptimal >= amountMin, '< minAmt');
    }
}
