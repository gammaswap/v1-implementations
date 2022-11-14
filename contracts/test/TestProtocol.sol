// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
pragma abicoder v2;

import "@gammaswap/v1-core/contracts/interfaces/IProtocol.sol";

contract TestProtocol is IProtocol {
    uint24 public override protocolId;
    address public override longStrategy;
    address public override shortStrategy;

    constructor(uint24 _protocolId, address _longStrategy, address _shortStrategy) {
        protocolId = _protocolId;
        longStrategy = _longStrategy;
        shortStrategy = _shortStrategy;
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens) {
        tokens = _tokens;
    }
}
