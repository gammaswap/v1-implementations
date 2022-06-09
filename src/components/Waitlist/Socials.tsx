import * as React from 'react';
import { faTwitter, faLinkedin } from '@fortawesome/free-brands-svg-icons';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import {
    VStack,
    HStack,
    Text,
    Box,
    Link,
} from '@chakra-ui/react';

const Socials: React.FC = () => {
    return (
        <VStack pt={40} spacing={8}>
            <Text
            as="h2"
            size="lg"
            lineHeight="tall"
            color="gray.500"
            fontWeight="medium"
            >
                Follow us!
            </Text>
            <HStack spacing='12'>
                <Link href="https://www.twitter.com/GammaSwapLabs">
                    <Box
                    fontSize='5xl'
                    color="gray.500"
                    >
                        <FontAwesomeIcon icon={faTwitter}/>
                    </Box>
                </Link>
                <Link href="#">
                    <Box
                    fontSize='5xl'
                    color="gray.500"
                    >
                        <FontAwesomeIcon icon={faLinkedin}/>
                    </Box>
                </Link>
            </HStack>
        </VStack>
    )
}

export default Socials