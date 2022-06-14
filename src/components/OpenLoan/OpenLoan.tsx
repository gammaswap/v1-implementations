import * as React from 'react';
import { Token, Tokens } from '../SelectToken/Token';

import {
    Box,
    Container,
    FormControl,
    Heading,
    List,
    ListItem,
    Center,
    FormLabel,
    Select,
    Button,
    ButtonGroup,
    Icon,
    Text,
    VStack,
    Input
} from '@chakra-ui/react';

import {
    FaInfoCircle,
} from 'react-icons/fa';

interface OpenLoanProps {
    handleOpenLoanConfirm: (token: Token) => any;
}

const OpenLoan: React.FC<OpenLoanProps> = (props) => {
    return (
        <Container>
            <Box borderRadius={'2xl'} bg={'#1d2c52'} maxW='450px' boxShadow='dark-lg'>
                <FormControl p='10px 15px 0px 15px' boxShadow='lg'>
                    <VStack>
                        <Heading color={'#e2e8f0'} marginBottom={'25px'}>Open Your Loan</Heading>
                        <FormLabel variant='openLoan'>Select a Token Pair</FormLabel>
                        <Container>
                            <Container w='50%' display='inline-block' ><Select color={'#e2e8f0'} placeholder='Select a token'/></Container>
                            <Container w='50%' display='inline-block' ><Select color={'#e2e8f0'} placeholder='Select a token'/></Container>
                        </Container>
                        <Container textAlign='center'>
                            <ButtonGroup variant='loanInfo' display='inline-block' size='tiny' >
                                <Button leftIcon={<FaInfoCircle />}>
                                    <Text pr='5px'>MaxLTV</Text>
                                    <Text >--%</Text>
                                </Button>
                                <Button leftIcon={<FaInfoCircle />}>
                                    <Text pr='5px'>Liquidation Threshold</Text>
                                    <Text >--%</Text>
                                </Button>
                                <Button leftIcon={<FaInfoCircle />}>
                                <Text pr='5px'>Liquidation Penalty</Text>
                                    <Text >--%</Text>
                                </Button>
                            </ButtonGroup>
                        </Container>
                        <FormLabel variant='openLoan'>Your Loan Amount</FormLabel>
                        <Input variant='outline' placeholder='0'></Input>
                        <FormLabel variant='openLoan'>Your Collateral</FormLabel>
                        <Input variant='outline' placeholder='0'></Input>
                        <Container p='20px' />
                        <Container textAlign='right'>
                            <Text variant='loanInfoRight' pr='5px'>Interest Rate</Text>
                            <Text variant='loanInfoRight' >--%</Text>
                        </Container>
                        <Container p='0 0 5px 0'>
                            <Button variant='confirmGrey' >Confirm</Button>
                        </Container>
                    </VStack>
                </FormControl>
            </Box >
        </Container>
    )
}

export default OpenLoan