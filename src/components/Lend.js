import React, { useEffect, useState, useCallback } from 'react'
import { useForm } from 'react-hook-form';
import * as Web3 from 'web3/dist/web3.min.js'
import IUniswapV2Pair from '../abis/IUniswapV2Pair.json';
import { BigNumber, constants } from 'ethers';
import {
    FormControl,
    FormLabel,
    Input,
    Button,
    Heading,
    Box
} from '@chakra-ui/react';

const ZEROMIN = 0;

function Lend({ account, depPool, token0, token1}) {
    const [liquidityAmt, setLiquidityAmt] = useState("0");
    const [liqInTokB, setLiqInTokB] = useState("0");
    const [uniPrice, setUniPrice] = useState("0");
    const { register, handleSubmit, reset } = useForm({
        defaultValues: {
            token0Amt: '0',
            token1Amt: '0',
        }
    });
    const { register: register2, handleSubmit: handleSubmit2 } = useForm({
        defaultValues: {
            balance: '0', 
        }
    });


    function pretty(num) {
        return Web3.utils.fromWei(num);
    }

    function sqrt(y){
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

    useEffect(() => {
        async function fetchData() {
            if(depPool && depPool.methods) {
                const liqBal = await depPool.methods.balanceOf(account).call();
                setLiquidityAmt(pretty(liqBal.toString()));
                const uniPair = await depPool.methods.getUniPair().call();
                console.log("uniPair >> ");
                console.log(uniPair);
                const uniPairContract = new web3.eth.Contract(IUniswapV2Pair.abi, uniPair);
                const reserves = await uniPairContract.methods.getReserves().call();
                console.log("reserves >>");
                console.log(reserves.reserve0);
                console.log(reserves.reserve1);
                const _uniPrice = BigNumber.from(reserves.reserve1).mul(BigNumber.from(10).pow(18)).div(reserves.reserve0);
                console.log("price >>");
                console.log(_uniPrice.toString());
                setUniPrice(_uniPrice.toString());
                const liqBalNum = BigNumber.from(liqBal.toString());
                if(liqBalNum.gt(constants.Zero) && _uniPrice.gt(constants.Zero)) {
                    setLiqInTokB(pretty((sqrt(_uniPrice.mul(BigNumber.from(10).pow(18))).mul(liqBalNum)
                        .div(BigNumber.from(10).pow(18))).mul(2).toString()));
                } else {
                    setLiqInTokB("0");
                }
            }
        }
        fetchData();
    },[depPool]);

    async function deposit({ token0Amt, token1Amt}) {
        const token0Allowance = await checkAllowance(account, token0);
        console.log("token0Allowance >> ");
        console.log(token0Allowance);
        if (token0Allowance <= 0) {
            console.log("approve for token0");
            await approve(token0, depPool._address)
        }

        const token1Allowance = await checkAllowance(account, token1);
        console.log("token1Allowance >> ");
        console.log(token1Allowance);
        if (token1Allowance <= 0) {
            console.log("approve for token1");
            await approve(token1, depPool._address)
        }

        const addLiquidity = await depPool
        .methods
        .addLiquidity(
            Web3.utils.toWei(token0Amt, "ether"),
            Web3.utils.toWei(token1Amt, "ether"),
            ZEROMIN,
            ZEROMIN,
            account
        ).send({ from: account })
        .then(res => {
            alert("Liquidity has been Deposited.")
            
        })
        .catch(err => {
            console.error(err)
        })


    }

    async function withdraw({ balance }) {
        await approveWithdraw(depPool, depPool._address)

        const removeLiquidity = await depPool
        .methods
        .removeLiquidity(
            Web3.utils.toWei(balance, "ether"),
            ZEROMIN,
            ZEROMIN,
            account
        )
        .send({ from: account })
        .then((res) => {
            console.log(res)
            return res
        })
        .catch(err => {
            console.error(err)
        })
    }

    async function approve(fromToken, toAddr) {
        console.log(fromToken);
        const res = await fromToken.contract.methods.approve(toAddr, constants.MaxUint256).send({ from: account });
        console.log("res >>");
        console.log(res);
    }

    async function approveWithdraw(depPool, depPoolAddr) {
        console.log(depPool);
        const res = await depPool.methods.approve(depPoolAddr, constants.MaxUint256.toString()).send({ from: account });
        console.log("withdraw res >>");
        console.log(res);
    }

    async function checkAllowance(account, token) {
        console.log("checking allowance...")
        if (token.symbol) console.log(token.symbol);
        const allowedAmt = await token
        .contract
        .methods
        .allowance(account, depPool._address)
        .call();
        /*.then(res => {
            console.log("check allowance " + token.symbol);
            console.log(res)
            return res
        })
        .catch(err => {
            console.log("IM HERE")
            console.error(err)
        })/**/
        console.log("allowedAmt >>");
        console.log(allowedAmt);
        return allowedAmt;
    }

    async function checkWithdrawAllowance(account, _depPool) {
        const allowedAmt = await _depPool
        .methods
        .allowance(account, depPool._address)
        .call()
        .then(res => {
            console.log(res)
            return res
        })
        .catch(err => {
            console.log("IM HERE")
            console.error(err)
        })
    }


    return (
        /*Lend LP Form */
        <>
            <Box borderRadius={'3xl'} bg={'#1d2c52'} boxShadow='dark-lg'>
                <form onSubmit={handleSubmit(deposit)}>
                    <FormControl p={14} boxShadow='lg'>
                        <Heading color={'#e2e8f0'} marginBottom={'25px'}>Deposit Tokens</Heading>
                        <FormLabel
                            color={'#e2e8f0'}
                            fontSize={'md'}
                            fontWeight={'semibold'}
                            htmlFor='token0'
                        >
                            {token0.symbol}
                        </FormLabel>
                        <Input
                            placeholder='amount'
                            color={'#e2e8f0'}
                            id='token0'
                            type='number'
                            {...register('token0Amt')}
                        />
                        <FormLabel
                            color={'#e2e8f0'}
                            fontSize={'md'}
                            fontWeight={'semibold'}
                            mt={5}
                            htmlFor='token1'
                        >
                            {token1.symbol}
                        </FormLabel>
                        <Input
                            placeholder='amount'
                            color={'#e2e8f0'}
                            id='token1'
                            type='number'
                            {...register('token1Amt')}
                        />
                        <Button
                            my={5}
                            colorScheme='blue'
                            type='submit'
                        >
                            Submit
                        </Button>
                    </FormControl>
                </form>
                <form onSubmit={handleSubmit2(withdraw)}>
                    <FormControl p={14}>
                        <Heading color={'#e2e8f0'} marginBottom={'25px'}>Withdraw Liquidity</Heading>
                        <FormLabel
                            color={'#e2e8f0'}
                            fontSize={'md'}
                            fontWeight={'semibold'}                        
                            mt={5}
                            htmlFor='balance'
                        >
                            <div>Balance in Liquidity: {liquidityAmt} </div>
                            <div>Balance in {token1 ? token1.symbol : ""}: {liqInTokB}</div>
                        </FormLabel>
                            <Input
                                id='balance'
                                color={'#e2e8f0'}
                                type='number'
                                {...register2('balance')}
                            />
                        <Button
                            my={5}
                            colorScheme='blue'
                            type='submit'
                        >
                            Submit
                        </Button>
                    </FormControl>
                </form>
            </Box>
        </>
    )
}
export default Lend;