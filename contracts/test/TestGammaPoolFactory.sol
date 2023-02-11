// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@gammaswap/v1-core/contracts/interfaces/IGammaPoolFactory.sol";

contract TestGammaPoolFactory is IGammaPoolFactory {
    address private protocol;

    mapping(bytes32 => address) public override getPool; // all GS Pools addresses can be predetermined
    uint16 public override fee = 10000; // Default value is 10,000 basis points or 10%
    address public override feeTo;
    address public override feeToSetter;
    address public override owner;

    constructor(address _feeToSetter, uint16 _fee){
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        fee = _fee;
        owner = msg.sender;
    }

    function createPool(uint16, address, address[] calldata, bytes calldata) external override virtual returns(address) {
        return address(0);
    }

    function isProtocolRestricted(uint16) external pure override returns(bool) {
        return false;
    }

    function setIsProtocolRestricted(uint16, bool) external override {
    }

    function addProtocol(address _protocol) external override {
        protocol = _protocol;
    }

    function removeProtocol(uint16) external override {
        protocol = address(0);
    }

    function getProtocol(uint16) external override view returns (address) {
        return protocol;
    }

    function allPoolsLength() external override pure returns (uint256) {
        return 0;
    }

    function feeInfo() external override view returns(address,uint) {
        return(feeTo, 0);
    }
}
