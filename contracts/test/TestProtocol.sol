// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IProtocol.sol";

contract TestProtocol is IProtocol {
    address public override longStrategy;
    address public override shortStrategy;
    uint24 public override protocol;

    struct Params{
        uint256 val;
    }

    constructor(address _longStrategy, address _shortStrategy, uint24 _protocol) {
        longStrategy = _longStrategy;
        shortStrategy = _shortStrategy;
        protocol = _protocol;
    }

    function initialize(bytes calldata protData, bytes calldata stratData, bytes calldata rateData) external virtual override returns(bool) {
        return true;
    }

    function parameters() external virtual override view returns(bytes memory params1, bytes memory params2,bytes memory params3) {
        params1 = abi.encode(Params({ val: 1}));
        params2 = abi.encode(Params({ val: 2}));
        params3 = abi.encode(Params({ val: 3}));
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens, bytes32 key) {
        tokens = _tokens;
        key = bytes32(uint256(1));
    }
}
