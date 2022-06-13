import * as React from 'react';
import { Token, Tokens } from './Token';

import {
    Box,
    Container,
    FormControl,
    Heading,
    List,
    ListItem,
    Center
} from '@chakra-ui/react';

interface SelectTokenProps {
    handleTokenSelected: (token: Token) => any;
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
                            <ListItem cursor="pointer" key={token.symbol} display='flex' p={1} onClick={() => props.handleTokenSelected(token)}> 
                                <Container p={0} w='80px'><img src={token.iconPath} /></Container>
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