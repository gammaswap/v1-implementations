import * as React from 'react';
import {
    Box,
    Button,
    Container,
    Link as ChakraLink,
    FormControl,
    Heading,
    FormLabel,
    Input,
} from '@chakra-ui/react';

const CrossChain = () => {
    return (
        <Container>
            <Box borderRadius={'3xl'} bg={'#1d2c52'} boxShadow='dark-lg'>
                <FormControl p={14} boxShadow='lg'>
                    <Heading color={'#e2e8f0'} marginBottom={'25px'}>Algorand to Ethereum Bridge w/ Wormhole</Heading>
                    <FormLabel
                        color={'#e2e8f0'}
                        fontSize={'md'}
                        fontWeight={'semibold'}
                        htmlFor='token_amount'
                    >
                        Token Amount
                    </FormLabel>
                    <Input
                        placeholder='1 ALGO'
                        color={'#e2e8f0'}
                        id='token_amount'
                        type='text'
                    />
                    <FormLabel
                        color={'#e2e8f0'}
                        fontSize={'md'}
                        fontWeight={'semibold'}
                        mt={5}
                        htmlFor='dest_address'
                    >
                        Destination Address
                    </FormLabel>
                    <Input
                        placeholder='0x...'
                        color={'#e2e8f0'}
                        id='dest_address'
                        type='text'
                    />
                    <Button
                        my={5}
                        colorScheme='blue'
                        type='submit'
                    >
                        Bridge
                    </Button>
                </FormControl>

            </Box >
        </Container>
    )
}

export default CrossChain