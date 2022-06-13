import * as React from 'react';
import { Token } from '../SelectToken/Token';
import { CollateralType } from './CollateralType';

import {
    Box,
    Container,
    FormControl,
    Heading,
    List,
    ListItem,
} from '@chakra-ui/react';

interface SelectCollateralProps {
    token0: Token;
    token1: Token;
    handleCollateralSelected: (type: CollateralType) => any;
}

const SelectToken: React.FC<SelectCollateralProps> = (props) => {
    return (
        <Container>
            <Box borderRadius={'3xl'} maxW='500px' bg={'#1d2c52'} boxShadow='dark-lg'>
                <FormControl p={14} boxShadow='lg'>
                    <Heading color={'#e2e8f0'} marginBottom={'25px'}>Select Collateral Type</Heading>
                    <List
                        color={'#e2e8f0'}
                        fontSize={'md'}
                        fontWeight={'semibold'}                        
                        mt={5}
                        cursor="pointer"
                    >
                        <ListItem key={CollateralType.LPToken} display='flex' p={1} onClick={() => props.handleCollateralSelected(CollateralType.LPToken)}> 
                            Liquidity Pool Tokens
                        </ListItem>
                        <ListItem key={CollateralType.Token0} display='flex' p={1} onClick={() => props.handleCollateralSelected(CollateralType.Token0)}> 
                            {props.token0.symbol} Token
                        </ListItem>
                        <ListItem key={CollateralType.Token1} display='flex' p={1} onClick={() => props.handleCollateralSelected(CollateralType.Token1)}> 
                            {props.token1.symbol} Token
                        </ListItem>
                        <ListItem key={CollateralType.Both} display='flex' p={1} onClick={() => props.handleCollateralSelected(CollateralType.Both)}> 
                            Both Tokens
                        </ListItem>

                    </List>
                </FormControl>
            </Box >
        </Container>
    )
}

export default SelectToken