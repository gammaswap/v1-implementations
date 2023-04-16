pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract UniswapSetup is Test {

    IUniswapV2Factory uniFactory;
    IUniswapV2Router02 uniRouter;
    IUniswapV2Pair uniPair;

    function initUniswap(address owner, address weth) public {
        // Let's do the same thing with `getCode`
        //bytes memory args = abi.encode(arg1, arg2);
        bytes memory factoryArgs = abi.encode(owner);
        bytes memory factoryBytecode = abi.encodePacked(vm.getCode("./node_modules/@uniswap/v2-core/build/UniswapV2Factory.json"), factoryArgs);
        address factoryAddress;
        assembly {
            factoryAddress := create(0, add(factoryBytecode, 0x20), mload(factoryBytecode))
        }

        bytes memory routerArgs = abi.encode(factoryAddress, weth);
        bytes memory routerBytecode = abi.encodePacked(vm.getCode("./node_modules/@uniswap/v2-periphery/build/UniswapV2Router02.json"), routerArgs);
        address routerAddress;
        assembly {
            routerAddress := create(0, add(routerBytecode, 0x20), mload(routerBytecode))
        }

        uniFactory = IUniswapV2Factory(factoryAddress);
        uniRouter = IUniswapV2Router02(routerAddress);
    }

    function createPair(address token0, address token1) public returns(address) {
        return IUniswapV2Factory(uniFactory).createPair(token0, token1);
    }

}
