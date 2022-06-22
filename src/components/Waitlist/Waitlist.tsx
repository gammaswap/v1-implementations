import * as React from 'react';
import {
    VStack,
    HStack,
    Box,
    Button,
    Link,
    Flex,
    Icon,
} from '@chakra-ui/react';
import Navbar from '../Navbar/Navbar';
import {
    FaTwitter,
    FaLinkedin,
    FaGithub,
} from 'react-icons/fa';

const Waitlist: React.FC = () => {
    return (
        <>
            <Navbar />
            <VStack
                spacing={8}
                alignItems="center"
                justifyContent="center"
                textAlign="center"
                pt={20}
                >
                <Box
                    textStyle={"h1"}
                    color={"gray.200"}
                >
                    A Decentralized
                </Box>
                <Box
                    textStyle={"display"}
                    color={"gray.100"}
                >
                    Volatility Exchange
                </Box>
                <Box>
                    <Link href={"https://4u44h1i583d.typeform.com/to/B6Uz3LKy"}
                          style={{textDecoration: "none"}}>
                        <Button
                            bgColor={"brand.primary"}
                            borderRadius={10}
                            mt={'10'}
                            h={20}
                            w={72}
                            >
                                <Box textStyle={"h3"} color={"gray.100"}>
                                    Get Notified at Launch
                                </Box>
                        </Button>
                    </Link>
                    <Box
                    textStyle={"h4"}
                    color={"gray.100"}
                    lineHeight={8}
                    px={["1em", 86]}
                    py={20}
                    >
                        GammaSwap is the first decentralized exchange that allows you to short or long crypto volatility
                        by providing or shorting liquidity from CFMMs like Uniswap, Sushiswap, Balancer, etc.
                    </Box>
                </Box>
            </VStack>
            <Flex
                direction={"row"}
                justify={["center","flex-end"]}
                mr={[0,"1em"]}
            >
                <HStack spacing={4} color={"gray.100"}>
                    <Link href={"https://www.twitter.com/gammaswaplabs"} target={"_blank"}>
                        <Icon w={7} h={7} as={FaTwitter} />
                    </Link>
                    <Link href={"https://www.linkedin.com/company/gammaswap-labs/"} target={"_blank"}>
                        <Icon w={7} h={7} as={FaLinkedin} />
                    </Link>
                    <Link href={"https://www.github.com/gammaswap"} target={"_blank"}>
                        <Icon w={7} h={7} as={FaGithub} />
                    </Link>
                </HStack>
            </Flex>
        </>
    )
}

export default Waitlist;