// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
pragma abicoder v2;

import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "@gammaswap/v1-core/contracts/protocols/AbstractProtocol.sol";
import "../interfaces/strategies/ICPMMStrategy.sol";
import "../interfaces/rates/ILinearKinkedRateModel.sol";

contract CPMMProtocol is AbstractProtocol {

    error NotContract();
    error BadProtocol();
    //0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    //0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303 SushiSwap

    /*struct CPMMProtocolParams {
        address factory;
        bytes32 initCodeHash;
        uint16 tradingFee1;
        uint16 tradingFee2;
        uint256 baseRate;
        uint256 optimalUtilRate;
        uint256 slope1;
        uint256 slope2;
    }/**/

    address immutable public factory;
    bytes32 immutable public initCodeHash;
    /*uint16 immutable public override tradingFee1;
    uint16 immutable public override tradingFee2;

    uint256 immutable public override baseRate;
    uint256 immutable public override optimalUtilRate;
    uint256 immutable public override slope1;
    uint256 immutable public override slope2;/**/

    //constructor(uint24 _protocolId, address longStrategy, address shortStrategy, bytes memory pData) AbstractProtocol(_protocolId, longStrategy, shortStrategy) {
    constructor(uint24 _protocolId, address longStrategy, address shortStrategy, address _factory, bytes32 _initCodeHash) AbstractProtocol(_protocolId, longStrategy, shortStrategy) {
        factory = _factory;
        initCodeHash = _initCodeHash;
        /*CPMMProtocolParams memory params = abi.decode(pData, (CPMMProtocolParams));
        factory = params.factory;
        initCodeHash = params.initCodeHash;
        /*tradingFee1 = params.tradingFee1;
        tradingFee2 = params.tradingFee2;
        baseRate = params.baseRate;
        optimalUtilRate = params.optimalUtilRate;
        slope1 = params.slope1;
        slope2 = params.slope2;/**/
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens) {
        if(!isContract(_cfmm)) {
            revert NotContract();
        }

        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        if(_cfmm != AddressCalculator.calcAddress(factory,keccak256(abi.encodePacked(tokens[0], tokens[1])),initCodeHash)) {
            revert BadProtocol();
        }
    }
}
