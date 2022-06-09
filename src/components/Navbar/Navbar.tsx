import DesktopNav from './Desktop/DesktopNav';
import MobileNav from './Mobile/MobileNav';
import {
    Box,
    Flex,
    Text,
    IconButton,
    Stack,
    Collapse,
    Icon,
    useColorModeValue,
    useBreakpointValue,
    useDisclosure,
} from "@chakra-ui/react";
import {
  HiMenu,
  HiX,
} from 'react-icons/hi';

const Navbar = () => {
    const { isOpen, onToggle } = useDisclosure();

    return (
        <Box>
            <Flex
                bg={useColorModeValue("white", "gray.800")}
                color={useColorModeValue("gray.600", "white")}
                minH={"60px"}
                py={{ base: 2 }}
                px={{ base: 4 }}
                borderBottom={1}
                borderStyle={"solid"}
                borderColor={useColorModeValue("gray.200", "gray.900")}
                align={"center"}
            >
                <Flex
                    flex={{ base: 1, md: "auto" }}
                    ml={{ base: -2 }}
                    display={{ base: "flex", md: "none" }}
                >
                    <IconButton
                        onClick={onToggle}
                        icon={
                            isOpen ? (
                                <Icon as={HiX} w={3} h={3} />
                            ) : (
                                <Icon as={HiMenu} w={5} h={5} />
                            )
                        }
                        variant={"ghost"}
                        aria-label={"Toggle Navigation"}
                    />
                </Flex>
                <Flex
                    flex={{ base: 1 }}
                    justify={{ base: "center", md: "start" }}
                >
                    <Text
                        textAlign={useBreakpointValue({
                            base: "center",
                            md: "left",
                        })}
                        textStyle={"h3"}
                        color={useColorModeValue("gray.800", "white")}
                    >
                        GammaSwap
                    </Text>

                    <Flex display={{ base: "none", md: "flex" }} ml={10}>
                        <DesktopNav />
                    </Flex>
                </Flex>

                <Stack
                    flex={{ base: 1, md: 0 }}
                    justify={"flex-end"}
                    direction={"row"}
                    spacing={6}
                >
                </Stack>
            </Flex>

            <Collapse in={isOpen} animateOpacity>
                <MobileNav />
            </Collapse>
        </Box>
    );
}

export default Navbar;
