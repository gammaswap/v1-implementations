// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/IProtocolModule.sol";

contract BalancerModule is IProtocolModule {

    address public immutable override factory;//protocol factory
    address public immutable override protocolFactory;//protocol factory
    uint24 public override protocol;

    constructor(address _factory, address _protocolFactory) {
        factory = _factory;
        protocolFactory = _protocolFactory;
        protocol = 3;
    }

    function at(address _addr) internal view returns (bytes memory o_code) {
        assembly {
        // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
        // allocate output byte array - this could also be done without assembly
        // by using o_code = new bytes(size)
            o_code := mload(0x40)
        // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
        // store length in memory
            mstore(o_code, size)
        // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }

    //TODO: Not finished
    function validateCFMM(address[] calldata _tokens, address _cfmm)  external view override returns(address[] memory tokens){
        /*require(type(BPool).bytecode == at(params.cfmm), 'BalancerModule.validateParams: INVALID_PROTOCOL_FOR_CFMM');
        tokens = BPool(params.cfmm).getFinalTokens();//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        salt = 0;/**/
    }

    function getKey(address _cfmm) external view override returns(bytes32 key) {
    }

    function getCFMM(address tokenA, address tokenB) external virtual override view returns(address cfmm) {
        cfmm = address(0);
    }

    function getCFMMInvariantChanges(address cfmm, uint256 lpTokenBal) external pure override returns(uint256 totalInvariant, uint256 newInvariant) {
    }

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        address cfmm,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin,
        address from
    ) external virtual override returns (uint[] memory amounts) {
        // create the pair if it doesn't exist yet
        /*amountA = 0;
        amountB = 0;
        cfmm = address(0);/**/
    }
}
