// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
pragma abicoder v2;

import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "@gammaswap/v1-core/contracts/protocols/AbstractProtocol.sol";

contract CPMMProtocol is AbstractProtocol {

    error NotContract();
    error BadProtocol();
    //0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    //0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303 SushiSwap

    address immutable public factory;
    bytes32 immutable public initCodeHash;

    constructor(uint24 _protocolId, address longStrategy, address shortStrategy, address _factory, bytes32 _initCodeHash) AbstractProtocol(_protocolId, longStrategy, shortStrategy) {
        factory = _factory;
        initCodeHash = _initCodeHash;
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
