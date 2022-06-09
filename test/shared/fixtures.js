/**
 * Created by danielalcarraz on 5/21/22.
 */
import { Contract, constants, BigNumber } from 'ethers';
import { formatBytes32String } from '@ethersproject/strings';
import { expandTo18Decimals } from './utilities';
const _contract = require('@truffle/contract');
//import  _contract from '@truffle/contract';
const Web3 = require("web3");
//import Web3 from 'web3';
const _provider = new Web3.providers.HttpProvider("http://localhost:7545");

//const ERC20Test = artifacts.require('./ERC20Test.sol');
const TestERC20 = artifacts.require('./TestERC20');
const TestDepositPool = artifacts.require('./TestDepositPool.sol');
//const VegaswapV1Pool = artifacts.require('./DepositPool.sol');
const TestPositionManager = artifacts.require('./TestPositionManager.sol');
//const VegaswapV1PositionDescriptor = artifacts.require('./VegaswapV1PositionDescriptor.sol');


const json1 = require("@uniswap/v2-core/build/UniswapV2Factory.json");//.bytecode;
const UniswapV2Factory = _contract(json1);
UniswapV2Factory.setProvider(_provider);

const json2 = require("@uniswap/v2-core/build/UniswapV2Pair.json");//.bytecode;
const UniswapV2Pair = _contract(json2);
UniswapV2Pair.setProvider(_provider);

const json3 = require("@uniswap/v2-periphery/build/UniswapV2Router02.json");//.bytecode;
const UniswapV2Router02 = _contract(json3);
UniswapV2Router02.setProvider(_provider);

const overrides = {
    gasPrice: 0,
};

//export async function factoryFixture(_: Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
/*export async function factoryFixture(address) {
    const weth = await TestERC20.new('WETH', 'WETH', expandTo18Decimals(10000));
    const uniFactory = await UniswapV2Factory.new(address, { from: address, gasPrice: 0 });
    const uniRouter = await UniswapV2Router02.new(uniFactory.address, weth.address, { from: address, gasPrice: 0 });
    const posDescriptor = await VegaswapV1PositionDescriptor.new(weth.address);
    //const factory = await VegaswapV1Factory.new(address, uniFactory.address, uniRouter.address, weth.address, posDescriptor.address);
    const factory = await TestVegaswapV1Factory.new(address, uniFactory.address, uniRouter.address, weth.address, posDescriptor.address, true);
    return { factory };
}/**/

//export async function factoryFixture(_: Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
/*export async function testFactoryFixture(address) {
    const weth = await TestERC20.new('WETH', 'WETH', expandTo18Decimals(10000));
    const uniFactory = await UniswapV2Factory.new(address, { from: address, gasPrice: 0 });
    const uniRouter = await UniswapV2Router02.new(uniFactory.address, weth.address, { from: address, gasPrice: 0 });
    const posDescriptor = await VegaswapV1PositionDescriptor.new(weth.address);
    const factory = await TestVegaswapV1Factory.new(address, uniFactory.address, uniRouter.address, weth.address, posDescriptor.address, false);
    return { factory };
}/**/

//export async function pairFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<PairFixture> {
export async function poolFixture(provider, address) {
    //const { factory } = await factoryFixture(address);

    const weth = await TestERC20.new('WETH', 'WETH', expandTo18Decimals(10000));
    const uniFactory = await UniswapV2Factory.new(address, { from: address });
    const uniRouter = await UniswapV2Router02.new(uniFactory.address, weth.address, { from: address });

    const tokenA = await TestERC20.new('COINA', 'COINA', expandTo18Decimals(10000));
    const tokenB = await TestERC20.new('COINB', 'COINB', expandTo18Decimals(10000));
    const token2 = await TestERC20.new('COINC', 'COINC', expandTo18Decimals(10000));

    await uniFactory.createPair(tokenA.address, tokenB.address, { from: address });
    const uniPairAddress = await uniFactory.getPair(tokenA.address, tokenB.address);

    const posManager = await TestPositionManager.new(uniRouter.address, { from: address });
    //address _uniRouter, address _uniPair, address _token0, address _token1, address _positionManager
    const pool = await TestDepositPool.new(uniRouter.address, uniPairAddress, tokenA.address, tokenB.address, posManager.address, { from: address });

    await posManager.registerPool(tokenA.address, tokenB.address, pool.address, { from: address});
    //const pool = new Contract(poolAddress, JSON.stringify(VegaswapV1Pool.abi), provider).connect(provider.getSigner(address));
    //const pool = new Contract(poolAddress, JSON.stringify(TestDepositPool.abi), provider).connect(provider.getSigner(address));

    //const uniPairAddress = await pool.uniPair();
    const uniPair = new Contract(uniPairAddress, JSON.stringify(UniswapV2Pair.abi), provider).connect(provider.getSigner(address));

    //const posManagerAddress = await factory.positionManager();
    //const posManager = new Contract(posManagerAddress, JSON.stringify(TestVegaswapV1Position.abi), provider).connect(provider.getSigner(address));

    const token0Address = (await pool.token0());
    const token0 = tokenA.address === token0Address ? tokenA : tokenB;
    const token1 = tokenA.address === token0Address ? tokenB : tokenA;


    //const uniRouterAddress = await factory.uniRouter();
    //const uniRouter = new Contract(uniRouterAddress, JSON.stringify(UniswapV2Router02.abi), provider).connect(provider.getSigner(address));
    //return { factory, token0, token1, token2, pool, uniPair, posManager, uniRouter };
    return { token0, token1, token2, pool, uniPair, posManager, uniRouter };
}

//export async function pairFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<PairFixture> {
/*export async function testPoolFixture(provider, address) {
    const { factory } = await testFactoryFixture(address);

    const tokenA = await TestERC20.new('COINA', 'COINA', expandTo18Decimals(100));
    const tokenB = await TestERC20.new('COINB', 'COINB', expandTo18Decimals(100));
    const token2 = await TestERC20.new('COINC', 'COINC', expandTo18Decimals(10000));

    await factory.createPool(tokenA.address, tokenB.address, overrides);
    const poolAddress = await factory.getPool(tokenA.address, tokenB.address);

    const pool = new Contract(poolAddress, JSON.stringify(TestDepositPool.abi), provider).connect(provider.getSigner(address));

    const uniPairAddress = await pool.uniPair();
    const uniPair = new Contract(uniPairAddress, JSON.stringify(UniswapV2Pair.abi), provider).connect(provider.getSigner(address));

    const posManagerAddress = await factory.positionManager();
    const posManager = new Contract(posManagerAddress, JSON.stringify(TestVegaswapV1Position.abi), provider).connect(provider.getSigner(address));

    const token0Address = (await pool.token0());
    const token0 = tokenA.address === token0Address ? tokenA : tokenB;
    const token1 = tokenA.address === token0Address ? tokenB : tokenA;

    const uniRouterAddress = await factory.uniRouter();
    const uniRouter = new Contract(uniRouterAddress, JSON.stringify(UniswapV2Router02.abi), provider).connect(provider.getSigner(address));

    return { factory, token0, token1, token2, pool, uniPair, posManager, uniRouter };
}/**/

//export async function pairFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<PairFixture> {
export async function testPoolFixture(provider, address) {
    //const { factory } = await factoryFixture(address);

    const weth = await TestERC20.new('WETH', 'WETH', expandTo18Decimals(10000));
    const uniFactory = await UniswapV2Factory.new(address, { from: address });
    const uniRouter = await UniswapV2Router02.new(uniFactory.address, weth.address, { from: address });

    const tokenA = await TestERC20.new('COINA', 'COINA', expandTo18Decimals(10000));
    const tokenB = await TestERC20.new('COINB', 'COINB', expandTo18Decimals(10000));
    const token2 = await TestERC20.new('COINC', 'COINC', expandTo18Decimals(10000));

    await uniFactory.createPair(tokenA.address, tokenB.address, { from: address });
    const uniPairAddress = await uniFactory.getPair(tokenA.address, tokenB.address);

    const posManager = await TestPositionManager.new(uniRouter.address, { from: address });
    //address _uniRouter, address _uniPair, address _token0, address _token1, address _positionManager
    const pool = await TestDepositPool.new(uniRouter.address, uniPairAddress, tokenA.address, tokenB.address, address, { from: address });
    //const pool = new Contract(poolAddress, JSON.stringify(VegaswapV1Pool.abi), provider).connect(provider.getSigner(address));
    //const pool = new Contract(poolAddress, JSON.stringify(TestDepositPool.abi), provider).connect(provider.getSigner(address));

    //const uniPairAddress = await pool.uniPair();
    const uniPair = new Contract(uniPairAddress, JSON.stringify(UniswapV2Pair.abi), provider).connect(provider.getSigner(address));

    //const posManagerAddress = await factory.positionManager();
    //const posManager = new Contract(posManagerAddress, JSON.stringify(TestVegaswapV1Position.abi), provider).connect(provider.getSigner(address));

    const token0Address = (await pool.token0());
    const token0 = tokenA.address === token0Address ? tokenA : tokenB;
    const token1 = tokenA.address === token0Address ? tokenB : tokenA;


    //const uniRouterAddress = await factory.uniRouter();
    //const uniRouter = new Contract(uniRouterAddress, JSON.stringify(UniswapV2Router02.abi), provider).connect(provider.getSigner(address));
    //return { factory, token0, token1, token2, pool, uniPair, posManager, uniRouter };
    return { token0, token1, token2, pool, uniPair, posManager, uniRouter };
}