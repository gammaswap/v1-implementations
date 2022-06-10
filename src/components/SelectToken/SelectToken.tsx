import * as React from 'react';
import Token from './Token';

import {
    Box,
    Container,
    FormControl,
    Heading,
    List,
    ListItem,
} from '@chakra-ui/react';

const Tokens: Array<Token> = [
    {
        iconPath: './crypto_icons/eth.png',
        symbol: 'ETH',
        address: "",
    },
    {
        iconPath: './crypto_icons/aave.png',
        symbol: 'AAVE',
        address: "",
    },
    {
        iconPath: './crypto_icons/bal.png',
        symbol: 'BAL',
        address: "",
    },
    {
        iconPath: './crypto_icons/uni.png',
        symbol: 'UNI',
        address: "",
    },
    {
        iconPath: './crypto_icons/usdt.png',
        symbol: 'USDT',
        address: "",
    },
    {
        iconPath: './crypto_icons/usdc.png',
        symbol: 'USDC',
        address: "",
    },
    {
        iconPath: './crypto_icons/sol.png',
        symbol: 'SOL',
        address: "",
    },
    {
        iconPath: './crypto_icons/bat.png',
        symbol: 'BAT',
        address: "",
    },
    {
        iconPath: './crypto_icons/link.png',
        symbol: 'LINK',
        address: "",
    },
    {
        iconPath: './crypto_icons/wbtc.png',
        symbol: 'WBTC',
        address: "",
    },
    {
        iconPath: './crypto_icons/matic.png',
        symbol: 'MATIC',
        address: "",
    },
    {
        iconPath: './crypto_icons/dai.png',
        symbol: 'DAI',
        address: "",
    },
];

interface SelectTokenProps {
    handleTokenSelected1: (token: Token) => any;
}

const SelectToken: React.FC<SelectTokenProps> = (props) => {
    return (
        <Container>
            <Box borderRadius={'3xl'} bg={'#1d2c52'} boxShadow='dark-lg'>
                <FormControl p={14} boxShadow='lg'>
                    <Heading color={'#e2e8f0'} marginBottom={'25px'}>Select a Token</Heading>
                    <List
                        color={'#e2e8f0'}
                        fontSize={'md'}
                        fontWeight={'semibold'}                        
                        mt={5}
                    >
                        {Tokens.map((token) => (
                            <ListItem cursor="pointer" key={token.symbol} display='flex' p={1} onClick={() => props.handleTokenSelected1(token)}> 
                                <Container p={0} w='32px'><img src={token.iconPath} /></Container>
                                <Container >{token.symbol}</Container> 
                                <Container textAlign='right'>0</Container> 
                            </ListItem>
                        ))}
                    </List>
                </FormControl>
            </Box >
        </Container>
    )
}

export default SelectToken