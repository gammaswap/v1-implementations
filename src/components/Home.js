import { Heading, VStack, Box } from '@chakra-ui/react';
import * as React from 'react'

function Home() {
    return (
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
                bgColor="blue.400"
                bgClip="text"
                fontSize="6xl"
                bgGradient="linear(to-l, #79c2ff, #4a5888)"
                >
                GammaSwap 🚀
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
                    Decentralized Volatility Exchange
                {/* I&apos;m a{" "}
                <Box as="span" color="gray.300">
                    Developer
                </Box>
                , who likes{" "}
                <Box as="span" color="gray.300">
                    Designing,{" "}
                </Box>{" "}
                <Box as="span" color="gray.300">
                    Writing
                </Box>{" "}
                and{" "}
                <Box as="span" color="gray.300">
                    Building Open Source
                </Box>{" "}
                projects. */}
                </Heading>
            </Box>
        </VStack>
    )

}
export default Home;