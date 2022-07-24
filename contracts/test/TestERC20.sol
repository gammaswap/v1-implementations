// SPDX-License-Identifier: GPL-V2
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

//import "hardhat/console.sol";

contract TestERC20 is ERC20 {

    address public owner;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_){
        owner = msg.sender;
        _mint(msg.sender, 100000 * (10 ** 18));
        //console.log("Deploying a Greeter with greeting:", _greeting);
        //console.log("Changing greeting from '%s' to '%s'", greeting, _greeting)
    }
}
