import React, { useState, useEffect } from 'react'
import { BigNumber, constants } from 'ethers'
import { useForm } from 'react-hook-form';
import * as Web3 from "web3/dist/web3.min.js";
import IUniswapV2Pair from '../abis/IUniswapV2Pair.json';
import {
    FormControl,
    FormLabel,
    Input,
    Button,
    Heading,
    Box
} from '@chakra-ui/react'

const ZEROMIN = 0;

function Borrow({ account, token0, token1, posManager }) {
    const [ liq1InTokB, setLiq1InTokB] = useState("0");
    const [ liq2InTokB, setLiq2InTokB] = useState("0");
    const [ posId, setPosId] = useState("");
    const [ balInTokB, setBalInTokB] = useState("0");
    const [ uniPrice, setUniPrice] = useState("0");
    const [ pos, setPos] = useState({});
    const { register, handleSubmit } = useForm();
    const { register: register2, handleSubmit: handleSubmit2 } = useForm();

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
            console.log("Borrow.fetchData() >>");
            if(posManager && posManager.methods) {
                const positionCount = await posManager.methods.positionCountByOwner(account).call();
                console.log("positionCount >>");
                console.log(positionCount);
                console.log(posManager);
                const positions = await posManager.methods.getPositionsByOwner(account).call();
                console.log("positions >>");
                console.log(positions);
                if(positionCount > 0) {
                    const position = await posManager.methods.positions(positionCount).call();
                    console.log("position() >>");
                    console.log(position);
                    setPos(position);
                    setPosId(positionCount.toString());
                    const uniPair = position.uniPair;
                    console.log("uniPair >> ");
                    console.log(uniPair);
                    const uniPairContract = new web3.eth.Contract(IUniswapV2Pair.abi, uniPair);
                    const reserves = await uniPairContract.methods.getReserves().call();
                    console.log("reserves >>");
                    console.log(reserves.reserve0);
                    console.log(reserves.reserve1);
                    const price = BigNumber.from(reserves.reserve1).mul(BigNumber.from(10).pow(18)).div(reserves.reserve0);
                    console.log("Borrow.price >>");
                    console.log(price.toString());
                    setUniPrice(price.toString());
                    const _uniPrice = BigNumber.from(price.toString());
                    if(_uniPrice.gt(constants.Zero)){
                        console.log('set balance in tokB');
                        const ONE = BigNumber.from(10).pow(18);
                        console.log("herer xxx0");
                        const squarePrice = sqrt(_uniPrice.mul(ONE));
                        console.log("herer xxx1");
                        const squarePrice2 = BigNumber.from(squarePrice.toString());
                        console.log("herer xxx2");
                        const posLiquidity = BigNumber.from(position.liquidity.toString());
                        const bal = (squarePrice2.mul(posLiquidity).div(ONE)).mul(2);
                        console.log("herer xxx3");
                        console.log("bal >> " + bal.toString());
                        setBalInTokB(pretty(bal.toString()));
                        console.log("herer xxx4");
                    }
                }
            }

        }
        fetchData();
    }, [posManager]);

    async function openPositionHandler({ token0Amt, token1Amt, liquidity }) {
        console.log("openPositionHandler() >>");
        console.log(token0Amt);
        console.log(token1Amt);
        console.log(liquidity);

        const token0Allowance = await checkAllowance(account, token0);
        console.log("token0Allowance >> ");
        console.log(token0Allowance);
        if (token0Allowance <= 0) {
            console.log("approve for token0");
            await approve(token0, posManager._address)
        }

        const token1Allowance = await checkAllowance(account, token1);
        console.log("token1Allowance >> ");
        console.log(token1Allowance);
        if (token1Allowance <= 0) {
            console.log("approve for token1");
            await approve(token1, posManager._address)
        }

        // TODO
        const createPosition = await posManager.methods.openPosition(
            token0.address,
            token1.address,
            Web3.utils.toWei(token0Amt, "ether"),
            Web3.utils.toWei(token1Amt, "ether"),
            Web3.utils.toWei(liquidity, "ether"),
            account,  
        ).send({ from: account });
        console.log("createPosition");
        console.log(createPosition);/**/
    }

    async function checkAllowance(account, token) {
        console.log("checking allowance...")
        if (token.symbol) console.log(token.symbol);
        const allowedAmt = await token
            .contract
            .methods
            .allowance(account, posManager._address)
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

    async function approve(fromToken, toAddr) {
        console.log(fromToken);
        const res = await fromToken.contract.methods.approve(toAddr, constants.MaxUint256).send({ from: account });
        console.log("res >>");
        console.log(res);
    }

    function handleLiq1Chng(evt) {
        console.log("handleLiq1Chng() >>");
        console.log(evt);
        const _uniPrice = BigNumber.from(uniPrice.toString());
        if(evt.length > 0 && _uniPrice.gt(constants.Zero)){
            const liq = BigNumber.from(evt.toString());
            setLiq1InTokB(pretty(sqrt(_uniPrice.mul(BigNumber.from(10).pow(18))).mul(liq).mul(2).toString()));
        } else {
            setLiq1InTokB("0");
        }
        //evt.preventDefault();
        //console.log("changeNum() >>");
        //console.log(evt);
        //setLiqInTokB(num.value);
    }

    function handleLiq2Chng(evt) {
        console.log("handleLiq2Chng() >>");
        console.log(evt);
        const _uniPrice = BigNumber.from(uniPrice.toString());
        if(evt.length > 0 && _uniPrice.gt(constants.Zero)){
            const liq = BigNumber.from(evt.toString());
            setLiq2InTokB(pretty(sqrt(_uniPrice.mul(BigNumber.from(10).pow(18))).mul(liq).mul(2).toString()));
        } else {
            setLiq2InTokB("0");
        }
        //evt.preventDefault();
        //console.log("changeNum() >>");
        //console.log(evt);
        //setLiqInTokB(num.value);
    }

    async function repayHandler({ repayLiquidity }) {
        // TODO
        console.log("repayHandler() >> ");
        console.log(repayLiquidity);
        console.log("posManager >>");
        console.log(posManager);

        console.log("pos >>");
        console.log(pos);
        console.log("pos.tokenId >>");
        console.log(pos.tokenId);
        const res = await posManager.methods.decreasePosition(posId,
            Web3.utils.toWei(repayLiquidity.toString(), "ether")).send({ from: account });
        console.log("res >>");
        console.log(res);
    }

    return (
        <>
            <Box borderRadius={'3xl'} bg={'#1d2c52'} boxShadow='dark-lg'>
                <form onSubmit={handleSubmit(openPositionHandler)}>
                    <FormControl p={14}>
                        <Heading marginBottom={'25px'}
                            color={'#e2e8f0'}
                        >
                            Open Loan
                        </Heading>
                        <FormLabel
                        color={'#e2e8f0'}
                        fontSize={'md'}
                        fontWeight={'semibold'}
                        htmlFor='token0'
                        >
                            Collateral {token0.symbol}
                        </FormLabel>
                        <Input
                            color={'#e2e8f0'}
                            placeholder='amount'
                            color={'#e2e8f0'}
                            id='token0'
                            type='number'
                            {...register('token0Amt')}
                        />
                        <FormLabel
                        color={'#e2e8f0'}
                        mt={5}
                        fontSize={'md'}
                        fontWeight={'semibold'}
                        htmlFor='token1'
                        >
                            Collateral {token1.symbol}
                        </FormLabel>
                        <Input
                            color={'#e2e8f0'}
                            placeholder='amount'
                            color={'#e2e8f0'}
                            id='token1'
                            type='number'
                            {...register('token1Amt')}
                        />
                        <FormLabel
                            color={'#e2e8f0'}
                            fontSize={'md'}
                            fontWeight={'semibold'}
                            mt={5}
                            htmlFor='liquidity'
                        >
                            Liquidity ({liq1InTokB} {token1 ? token1.symbol : "" })
                        </FormLabel>
                        <Input
                            color={'#e2e8f0'}
                            placeholder='amount'
                            color={'#e2e8f0'}
                            id='liquidity'
                            type='number'
                            {...register('liquidity')}
                            onChange={e => handleLiq1Chng(e.target.value)}
                        />
                        <Button
                            mt={10}
                            bgColor='#2563eb'
                            color='#e2e8f0'
                            type='submit'
                        >
                            Submit
                        </Button>
                    </FormControl>
                </form>
                <Heading  as='h5' fontFamily="body" size='md' color={'#e2e8f0'}>Balance: {balInTokB} {token1 ? token1.symbol : ""}</Heading>
                <Heading  as='h5' fontFamily="body" size='md' color={'#e2e8f0'}>Liquidity: {pos.liquidity ? pretty(pos.liquidity) : 0} </Heading>
                <form onSubmit={handleSubmit2(repayHandler)}>
                    <FormControl p={14} boxShadow='lg' mt={10}>
                        <Heading color={'#e2e8f0'} marginBottom={'25px'}>Repay Loan</Heading>
                        <FormLabel
                            color={'#e2e8f0'}
                            fontSize={'md'}
                            fontWeight={'semibold'}
                            mt={5}
                            htmlFor='repayLiquidity'
                        >
                            Liquidity ({liq2InTokB} {token1 ? token1.symbol : "" })
                        </FormLabel>
                            <Input
                                id='repayLiquidity'
                                placeholder='amount'
                                color={'#e2e8f0'}
                                type='number'
                                {...register2('repayLiquidity')}
                                onChange={e => handleLiq2Chng(e.target.value)}
                            />
                        <Button
                            my={5}
                            bgColor='#2563eb'
                            color='#e2e8f0'
                            type='submit'
                        >
                            Submit
                        </Button>
                    </FormControl>
                </form>
            </Box>
        </>
    );

}
export default Borrow;