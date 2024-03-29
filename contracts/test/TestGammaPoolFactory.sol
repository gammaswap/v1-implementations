// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/interfaces/IGammaPoolFactory.sol";
import "@gammaswap/v1-core/contracts/rates/storage/AbstractRateParamsStore.sol";

contract TestGammaPoolFactory is IGammaPoolFactory, AbstractRateParamsStore {
    address private protocol;

    mapping(bytes32 => address) public override getPool; // all GS Pools addresses can be predetermined
    mapping(address => bytes32) public override getKey; // all GS Pools addresses can be predetermined
    uint16 public override fee = 10000; // Default value is 10,000 basis points or 10%
    address public override feeTo;
    address public override feeToSetter;
    uint16 public override origFeeShare = 500;
    address public owner;

    constructor(address _feeToSetter, uint16 _fee){
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        fee = _fee;
        owner = msg.sender;
    }

    function execute(address _pool, bytes calldata _data) external {
    }

    function pausePoolFunction(address _pool, uint8 _functionId) external override virtual returns(uint256 _functionIds) {

    }

    function unpausePoolFunction(address _pool, uint8 _functionId) external override virtual returns(uint256 _functionIds) {

    }

    function updateProtocol(uint16 _protocolId, address _newImplementation) external override virtual {
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

    function lockProtocol(uint16) external override {
    }

    function getProtocol(uint16) external override view returns (address) {
        return protocol;
    }

    function getProtocolBeacon(uint16) external override view returns (address) {
        return address(0);
    }

    function allPoolsLength() external override pure returns (uint256) {
        return 0;
    }

    function feeInfo() external virtual override view returns(address, uint256, uint256) {
        return(feeTo, 0, 0);
    }

    function setPoolFee(address _pool, address _to, uint16 _protocolFee, uint16 _origFeeShare, bool _isSet) external override virtual {

    }

    function getPoolFee(address) external override virtual view returns (address _to, uint256 _protocolFee, uint256 _origFeeShare, bool _isSet) {
        return(feeTo, 0, 0, false);
    }

    function getPools(uint256 start, uint256 end) external virtual override view returns(address[] memory _pools) {
    }

    function _rateParamsStoreOwner() internal override virtual view returns(address) {
        return owner;
    }

    function setFee(uint16 _fee) external virtual override {
        fee = _fee;
    }

    function setFeeTo(address _feeTo) external virtual override {
        feeTo = _feeTo;
    }

    function setOrigFeeShare(uint16 _origFeeShare) external virtual override {
        origFeeShare = _origFeeShare;
    }

    function setFeeToSetter(address _feeToSetter) external virtual override {
        feeToSetter = _feeToSetter;
    }
}
