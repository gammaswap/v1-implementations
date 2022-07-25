pragma solidity ^0.8.0;

import "./GammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";

contract PoolDeployer {
    address public feeToSetter;
    address public owner;
    address private feeTo;
    uint256 private fee = 5 * (10**16); //5% of borrowed interest gains by default

    mapping(uint24 => address) public getProtocol;//there's a protocol
    mapping(bytes32 => address) public getPool;//all GS Pools addresses can be predetermined
    mapping(uint24 => bool) public isProtocolRestricted;//a protocol creation can be restricted

    address[] public allPools;

    IGammaPoolFactory.Parameters private _params;

    address public deployer;

    address public immutable factory;//TODO: Not sure if this will cause an issue when called as delegate since the other fields are not defined here
    //maybe we can test with removing everything else and just leaving factory here. Worry is that factory is being overwritten by data from caller
    //probably not though since this is supposed to be written inline during creation

    constructor(){
        factory = msg.sender;
    }

    function createPool(bytes32 key) external virtual returns (address pool) {
        require(address(this) == factory);//only runs as delegate to its creator
        pool = address(new GammaPool{salt: key}());//This is fine because the address is tied to the factory contract here. If the factory didn't create it, it will have a different address.
    }
}
