// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IProtocolModule.sol";
import "../libraries/PoolAddress.sol";
import "./UniswapV2LongGammaModule.sol";
import "./UniswapV2ShortGammaModule.sol";

contract UniswapV2Module is IProtocolModule {

    address public immutable override factory;//protocol factory
    address public immutable override protocolFactory;//protocol factory
    uint24 public immutable override protocol;
    bytes32 public immutable override initCodeHash;

    UniswapV2LongGammaModule public longStrategy;
    UniswapV2ShortGammaModule public shortStrategy;

    //0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    //0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303 SushiSwap
    constructor(address _factory, address _protocolFactory, uint24 _protocol, bytes32 _initCodeHash) {
        factory = _factory;
        protocolFactory = _protocolFactory;
        protocol = _protocol;//address factory, address protocolFactory, uint24 protocol, bytes32 initCodeHash
        initCodeHash = _initCodeHash;
        longStrategy = new UniswapV2LongGammaModule(_factory, _protocolFactory, _protocol, _initCodeHash);
        shortStrategy = new UniswapV2ShortGammaModule(_factory, _protocolFactory, _protocol, _initCodeHash);
    }

    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external override view returns(address[] memory tokens, bytes32 key){
        require(isContract(_cfmm) == true, 'not contract');
        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        UniswapV2Storage.UniswapV2Store storage store = UniswapV2Storage.store();
        require(_cfmm == PoolAddress.computeAddress(protocolFactory,keccak256(abi.encodePacked(tokens[0], tokens[1])),store.initCodeHash), 'bad protocol');
        key = PoolAddress.getPoolKey(_cfmm, store.protocol);
    }
}
