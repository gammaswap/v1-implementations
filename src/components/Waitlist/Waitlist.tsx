import * as React from 'react';
import { VStack, Heading, Box, Button, Link, Container } from '@chakra-ui/react';
import Navbar from '../Navbar/Navbar';

const Waitlist: React.FC = () => {
    return (
        <>
            <Navbar />
            <Box textStyle="display" color="brand.primary">GammaSwap</Box>
            <Box textStyle="h1" color="brand.secondary">GammaSwap</Box>
            <Box textStyle="h2" color="brand.tertiary">GammaSwap</Box>
            <Box textStyle="h3" color="brand.quaternary">GammaSwap</Box>
            <Box textStyle="h4" color="brand.quinary">GammaSwap</Box>
            <Box textStyle="body_base" color="brand.firstaccent">GammaSwap</Box>
            <Box textStyle="body_sm" color="brand.secondaccent">GammaSwap</Box>
            <Box textStyle="body_label" color="brand.primary">GammaSwap</Box>
            <Box textStyle="body_instruction" color="brand.primary">GammaSwap</Box>
            <Container>
                <VStack
                    spacing={8}
                    alignItems="center"
                    justifyContent="center"
                    textAlign="center"
                    pt={24}
                    pb={12}
                    >
                    <Box>
                        <Heading
                        as="h1"
                        fontFamily="body"
                        bgClip="text"
                        fontSize="6xl"
                        bgGradient="linear(to-l, #79c2ff, #4a5888)"
                        >
                        The Gamma Way. 
                        </Heading>
                    </Box>
                    <Box>
                        <Heading
                        as="h2"
                        size="lg"
                        lineHeight="tall"
                        color="gray.500"
                        fontWeight="medium"
                        >
                            GammaSwap is the newest decentralized platform that allows you to buy and sell volatility under the Uniswap protocol. Earn yields while migitating your risk.
                        </Heading>
                        <Link href='https://linktr.ee/gammaswap'>
                            <Button
                            colorScheme='blue'
                            mt={'10'}
                            size={'lg'}
                            >
                                Get Notified at Launch
                            </Button>
                        </Link>
                    </Box>
                </VStack>
            </Container>
        </>
    )
}

export default Waitlist;