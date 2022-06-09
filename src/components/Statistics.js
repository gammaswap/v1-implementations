//import * as React from 'react';
import React, { useState, useEffect } from 'react'
import { BigNumber, constants } from 'ethers'
import {
    Container,
    Stack,
    Heading,
    Text
} from '@chakra-ui/react';
import IUniswapV2Pair from '../abis/IUniswapV2Pair.json';
import Web3 from "web3/dist/web3.min.js";

function Statistics(props) {

    const [availToBorrow, setAvailToBorrow] = useState("0");
    const [availLiqToBorrow, setAvailLiqToBorrow] = useState("0");
    const [totalLiq, setTotalLiq] = useState("0");
    const [totalFunds, setTotalFunds] = useState("0");
    const [utilRate, setUtilRate] = useState("0");
    const [borrowRate, setBorrowRate] = useState("0");
    const [uniShare, setUniShare] = useState("0");
    const [uniPrice, setUniPrice] = useState("0");
    const [uniTokAReserves, setUniTokAReserves] = useState("0");
    const [uniTokBReserves, setUniTokBReserves] = useState("0");

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
            // You can await here
            console.log("fetchData");
            if(props.depPool && props.depPool.methods) {

                const uniPair = await props.depPool.methods.getUniPair().call();
                console.log("uniPair >> ");
                console.log(uniPair);
                const uniPairContract = new web3.eth.Contract(IUniswapV2Pair.abi, uniPair);
                const reserves = await uniPairContract.methods.getReserves().call();
                console.log("reserves >>");
                console.log(reserves.reserve0);
                console.log(reserves.reserve1);
                setUniTokAReserves(reserves.reserve0);
                setUniTokBReserves(reserves.reserve1);
                const price = BigNumber.from(reserves.reserve1).mul(BigNumber.from(10).pow(18)).div(reserves.reserve0);
                console.log("price >>");
                console.log(price.toString());
                setUniPrice(price.toString());
                const decimalPrice = price.div(BigNumber.from(10).pow(18)).toString();
                console.log("decimalPrice >>");
                console.log(decimalPrice);

                const totalUniLiquidity = await props.depPool.methods.totalUniLiquidity().call();
                console.log("totalUniLiquidity >> ");
                console.log(totalUniLiquidity);
                const UNI_LP_BORROWED = await props.depPool.methods.UNI_LP_BORROWED().call();
                console.log("UNI_LP_BORROWED >> ");
                console.log(UNI_LP_BORROWED);
                setTotalLiq(BigNumber.from(totalUniLiquidity.toString()).add(BigNumber.from(UNI_LP_BORROWED.toString())));
                if(BigNumber.from(totalUniLiquidity.toString()).gt(constants.Zero)) {
                    setAvailLiqToBorrow(totalUniLiquidity.toString());
                    const _borrowRate = await props.depPool.methods.getBorrowRate().call();
                    console.log("_borrowRate >> ");
                    console.log(_borrowRate.toString());//this is a yearly rate that is added on top of the uni yield
                    setBorrowRate(BigNumber.from(_borrowRate.toString()).mul(100).toString());
                    const utilizationRate = await props.depPool.methods.getUtilizationRate().call();
                    console.log("utilizationRate >> ");
                    console.log(utilizationRate);
                    setUtilRate(BigNumber.from(utilizationRate.toString()).mul(100).toString());
                    const BORROWED_INVARIANT = await props.depPool.methods.BORROWED_INVARIANT().call();
                    console.log("BORROWED_INVARIANT >> ");
                    console.log(BORROWED_INVARIANT);
                    const priceSquare = sqrt(price.mul(BigNumber.from(10).pow(18)));
                    console.log("priceSquare >>");
                    console.log(priceSquare.toString());
                    const borrowedFunds = ((BigNumber.from(BORROWED_INVARIANT.toString()).mul(priceSquare))
                        .div(BigNumber.from(10).pow(18))).mul(2);
                    console.log("borrowedFunds >>");
                    console.log(borrowedFunds.toString());
                    //BigNumber.from(BORROWED_INVARIANT.toString()).mul()
                    //invariant calculated from reserves. (part of pool that belongs to us is balance from uniPair)
                    const uniTotalSupply = await uniPairContract.methods.totalSupply().call();
                    console.log(uniTotalSupply);
                    const uniLpSharesInGamma = await uniPairContract.methods.balanceOf(props.depPool._address).call();
                    console.log(uniLpSharesInGamma);
                    const poolShare = BigNumber.from(uniLpSharesInGamma.toString()).mul(BigNumber.from(10).pow(18))
                        .div(BigNumber.from(uniTotalSupply.toString()));
                    console.log("poolShare >>");
                    console.log(poolShare.toString());//pool share percentage (in decimal)
                    setUniShare(BigNumber.from(poolShare.toString()).mul(100).toString());
                    const totalUniFunds = BigNumber.from(reserves.reserve1).mul(2);
                    console.log("totalUniFunds >> ")
                    console.log(totalUniFunds.toString());
                    const totalGammaFundsInUni = totalUniFunds.mul(poolShare).div(BigNumber.from(10).pow(18));
                    console.log("totalGammaFundsInUni >>");
                    console.log(totalGammaFundsInUni.toString());
                    const totalGammaFunds = borrowedFunds.add(totalGammaFundsInUni);
                    console.log("totalGammaFunds >> ");
                    console.log(totalGammaFunds.toString());
                    setTotalFunds(totalGammaFunds.toString());
                    const leftOverRate = (BigNumber.from(10).pow(18)).sub(BigNumber.from(utilizationRate.toString()));
                     console.log("leftOverRate >> ");
                     console.log(leftOverRate.toString());
                     const _availToBorrow = totalGammaFunds.mul(leftOverRate).div(BigNumber.from(10).pow(18));
                     console.log("_availToBorrow >>");
                     console.log(_availToBorrow.toString());
                     setAvailToBorrow(_availToBorrow.toString());
                     //TotalFunds: convert(BORROWED_INVARIANT + invariant in Uni that belongs to us. Total Pool Funds)
                     //Available to Borrow: (1 - UtilizationRate) * TotalFunds
                     /**/
                }
            }
        }
        fetchData();
    }, [props.depPool]);

    return (
        <div>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Total Funds: {pretty(totalFunds)} {props.token1.symbol}</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Avail To Borrow: {pretty(availToBorrow)} {props.token1.symbol}</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Total Uni Liq Shares in Pool: {pretty(totalLiq.toString())}</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Avail Uni Liq Shares To Borrow: {pretty(availLiqToBorrow)}</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Utilization Rate: {pretty(utilRate)}%</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Borrow Rate: {pretty(borrowRate)}%</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Share of Uni Pool: {pretty(uniShare)}%</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Price: {pretty(uniPrice)} {props.token1.symbol}</Heading>
            <Heading margin={'15px'}  as='h5' fontFamily="body" size='sm' color={'#e2e8f0'}>
                Uni Reserves: {pretty(uniTokAReserves)} {props.token0.symbol} / {pretty(uniTokBReserves)} {props.token1.symbol}</Heading>
    </div>);
}

export default Statistics
