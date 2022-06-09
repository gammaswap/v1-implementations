import * as React from 'react';
import {
    Container,
    Stack,
    Heading,
    Text
} from '@chakra-ui/react';

function About() {
    return (
        <Container>
            <Heading
                    as="h1"
                    fontFamily="body"
                    color="#e2e8f0"
                    fontSize="6xl"
                >
                    What makes GammaSwap so Great?
            </Heading>
            <Stack>
                <Text
                    as="p"
                    fontFamily="body"
                    color="#94a3b8"
                    fontSize="2xl"
                >
                The value in GammaSwap is to allow traders to buy volatility from Uniswap. This would be achieved by using the GammaSwap pool (GSP). In short, liquidity lenders will provide liquidity to Uniswap via GSP. It is a novel product to separate the embedded call and put options from an Uniswap liquidity pool so that liquidity providers and speculators can better hedge their risk exposures.
               </Text>
            </Stack>
        </Container>
    )
}

export default About
