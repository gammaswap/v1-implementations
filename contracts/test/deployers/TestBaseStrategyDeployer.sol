// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../strategies/TestBaseStrategy.sol";

contract TestBaseStrategyDeployer {

    address public immutable factory;

    constructor(){
        factory = msg.sender;
    }

    function createPool() external virtual returns (address pool) {
        require(address(this) == factory);//only runs as delegate to its creator.
        pool = address(new TestBaseStrategy());//This is fine because the address is tied to the factory contract here. If the factory didn't create it, it will have a different address.
    }
}
