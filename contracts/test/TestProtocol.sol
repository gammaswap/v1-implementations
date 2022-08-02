pragma solidity ^0.8.0;

import "../interfaces/strategies/IProtocol.sol";

contract TestProtocol is IProtocol {
    address public override longStrategy;
    address public override shortStrategy;
    uint24 public override protocol;

    constructor(address _longStrategy, address _shortStrategy, uint24 _protocol) {
        longStrategy = _longStrategy;
        shortStrategy = _shortStrategy;
        protocol = _protocol;
    }

    function initialize(bytes calldata protData, bytes calldata stratData, bytes calldata rateData) external virtual override returns(bool) {
        return true;
    }

    function parameters() external virtual override view returns(bytes memory,bytes memory,bytes memory) {
        return(bytes(uint256(1)),bytes(uint256(2)),bytes(uint256(3)));
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens, bytes32 key) {
        tokens = _tokens;
        key = bytes32(uint256(1));
    }
}
