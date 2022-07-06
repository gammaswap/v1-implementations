// SPDX-License-Identifier: BSD
pragma solidity ^0.8.0;

import './libraries/GammaSwapLibrary.sol';
import "./interfaces/IGammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./base/GammaPoolERC20.sol";

contract GammaPool is GammaPoolERC20, IGammaPool {

    uint public constant ONE = 10**18;
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    address public factory;
    address public token0;
    address public token1;
    uint24 public protocol;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public owner;

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'GammaPool: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        (factory, token0, token1, protocol) = IGammaPoolFactory(msg.sender).parameters();
        owner = msg.sender;
    }

    function mint(address to) external virtual override returns(uint256 liquidity) {
        address _to = to;
        liquidity = 1;
    }
}
