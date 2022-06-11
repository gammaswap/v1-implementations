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
                    The First 
                </Box>
                <Box
                    textStyle={"display"}
                    color={"gray.100"}
                >
                    Volatility Exchange. 
                </Box>
                <Box>
                    <Link href='https://linktr.ee/gammaswap'>
                        <Button
                        bgColor={"brand.primary"}
                        borderRadius={10}
                        mt={'10'}
                        h={20}
                        w={72}
                        >
                            <Link href={"https://4u44h1i583d.typeform.com/to/B6Uz3LKy"}>
                                <Box textStyle={"h3"} color={"gray.100"}>
                                    Get Notified at Launch
                                </Box>
                            </Link>
                        </Button>
                    </Link>
                    <Box
                    textStyle={"h4"}
                    color={"gray.100"}
                    lineHeight={8}
                    px={96}
                    py={20}
                    >
                        GammaSwap is the newest decentralized platform that allows you to buy and sell volatility under the Uniswap protocol. Earn yields while migitating your risk.
                    </Box>
                </Box>
            </VStack>
            <Flex
                direction={"row"}
                justify={"flex-end"}
                mr={20}
            >
                <HStack spacing={4} color={"gray.100"}>
                    <Link href={"https://www.twitter.com/gammaswaplabs"}>
                        <Icon w={7} h={7} as={FaTwitter} />
                    </Link>
                    <Link href={"https://www.linkedin.com/company/gammaswap-labs/"}>
                        <Icon w={7} h={7} as={FaLinkedin} />
                    </Link>
                    <Link href={"https://www.github.com/gammaswap"}>
                        <Icon w={7} h={7} as={FaGithub} />
                    </Link>
                </HStack>
            </Flex>
        </>
    )
}

export default Waitlist;