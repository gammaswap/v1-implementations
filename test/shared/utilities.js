/**
 * Created by danielalcarraz on 5/21/22.
 */
import { Contract, BigNumber, utils, providers } from 'ethers'

const PERMIT_TYPEHASH = utils.keccak256(
    utils.toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
);

export function expandTo18Decimals(n) {
    return BigNumber.from(n).mul(BigNumber.from(10).pow(18))
}

function getDomainSeparator(name, tokenAddress) {
    return utils.keccak256(
        utils.defaultAbiCoder.encode(
            ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
            [
                utils.keccak256(utils.toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
                utils.keccak256(utils.toUtf8Bytes(name)),
                utils.keccak256(utils.toUtf8Bytes('1')),
                1,
                tokenAddress,
            ]
        )
    )
}

export function getCreate2Address(//all args are strings
    factoryAddress,
    [tokenA, tokenB],
    bytecode
) {
    const [token0, token1] = tokenA < tokenB ? [tokenA, tokenB] : [tokenB, tokenA];
    const create2Inputs = [
        '0xff',
        factoryAddress,
        utils.keccak256(utils.solidityPack(['address', 'address'], [token0, token1])),
        utils.keccak256(bytecode),
    ];
    const sanitizedInputs = `0x${create2Inputs.map((i) => i.slice(2)).join('')}`
    return utils.getAddress(`0x${utils.keccak256(sanitizedInputs).slice(-40)}`)
}

export async function getApprovalDigest(
    token,//: Contract,
    approve,/*: {
     owner//: string
     spender//: string
     value//: BigNumber
     },/**/
    nonce,//: BigNumber,
    deadline,//: BigNumber
)
//: Promise<string>
{
    const name = await token.name();
    const DOMAIN_SEPARATOR = getDomainSeparator(name, token.address)
    return utils.keccak256(
        utils.solidityPack(
            ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
            [
                '0x19',
                '0x01',
                DOMAIN_SEPARATOR,
                utils.keccak256(
                    utils.defaultAbiCoder.encode(
                        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
                        [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
                    )
                ),
            ]
        )
    )
}


//export async function mineBlock(provider: Web3Provider, timestamp: number): Promise<void> {
export async function mineBlock(web3, timestamp) {
    await new Promise(async (resolve, reject) => {
        //;(provider._web3Provider.sendAsync as any)(
        //;(provider._web3Provider.sendAsync)(
        //;(provider.sendAsync)(
        ;(web3.currentProvider.send)(
            //;(provider.send)(
            { jsonrpc: '2.0', method: 'evm_mine', params: [timestamp] },
            //(error: any, result: any): void => {
            (error, result) => {
                if (error) {
                    reject(error)
                } else {
                    resolve(result)
                }
            }
        )
    })
}
/*
 async function mineBlock2(addSeconds) {
 const id = Date.now();

 return new Promise((resolve, reject) => {
 web3.currentProvider.send({
 jsonrpc: '2.0',
 method: 'evm_increaseTime',
 params: [addSeconds]
 }, (err1) => {
 if(err1) return reject(err1);

 web3.currentProvider.send({
 jsonrpc: '2.0',
 method: 'evm_min',
 id: id + 1,
 }, (err2, res) => (err2 ? reject(err2) : resolve(res)));
 });
 });
 }/**/

//export function encodePrice(reserve0: BigNumber, reserve1: BigNumber) {
export function encodePrice(reserve0, reserve1, timeElapsed) {
    return [(reserve1.mul(BigNumber.from(2).pow(112)).div(reserve0)).mul(timeElapsed), (reserve0.mul(BigNumber.from(2).pow(112)).div(reserve1)).mul(timeElapsed)]
}

// babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
export function sqrt(y){
    let z;
    if (y.gt(3)) {
        z = y;
        let x = (y.div(2)).add(1);
        while (x.lt(z)) {
            z = x;
            x = ((y.div(x)).add(x)).div(2);
        }
    } else if (!y.isZero()) {
        z = BigNumber.from(1);
    }
    return z;
}