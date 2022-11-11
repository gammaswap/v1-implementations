// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../strategies/TestShortStrategy.sol";

contract TestShortStrategyDeployer {

    address public immutable factory;

    constructor(address _factory){
        factory = _factory;
    }

    function createPool() external virtual returns (address pool) {
        require(address(this) == factory);//only runs as delegate to its creator.
        pool = address(new TestShortStrategy());//This is fine because the address is tied to the factory contract here. If the factory didn't create it, it will have a different address.
    }
}
