import DesktopNav from './Desktop/DesktopNav';
import MobileNav from './Mobile/MobileNav';
import {
    Box,
    Flex,
    IconButton,
    Collapse,
    Icon,
    useColorModeValue,
    useDisclosure,
    Image,
} from "@chakra-ui/react";
import {
  HiMenu,
  HiX,
} from 'react-icons/hi';

const Navbar = () => {
    const { isOpen, onToggle } = useDisclosure();
    const logoColor = useColorModeValue("gray.100", "gray.100")

    return (
        <Box>
            <Flex
                bg={useColorModeValue("gray.800", "gray.800")}
                color={useColorModeValue("gray.600", "white")}
                py={{ base: 2 }}
                px={{ base: 4 }}
                align={"center"}
            >
                <Flex
                    flex={{ base: 1, md: "auto" }}
                    ml={{ base: -2 }}
                    display={{ base: "flex", md: "none" }}
                >
                    <IconButton
                        onClick={onToggle}
                        colorScheme={"purple"}
                        icon={
                            isOpen ? (
                                <Icon as={HiX} color={"gray.100"} _hover={{ color: "gray.700" }} w={5} h={5} />
                            ) : (
                                <Icon as={HiMenu} color={"gray.100"} _hover={{ color: "gray.700" }} w={5} h={5} />
                            )
                        }
                        variant={"ghost"}
                        aria-label={"Toggle Navigation"}
                    />
                </Flex>
                <Flex
                    flex={{ base: 1 }}
                    justify={{ base: "center", md:"flex-start"}}
                >
                    <Image w={"40px"} src={"/assets/gsLogo.png"} alt={"GammaSwap Logo"} />
                    <Box
                        textStyle={"h3"}
                        ml={1}
                        pt={1}
                        color={logoColor}
                    >
                        GammaSwap
                    </Box>
                </Flex>
                <Flex
                    flex={{ base: 1 }}
                    justify={{ base: "center", md: "flex-end" }}
                >
                    <Flex display={{ base: "none", md: "flex" }} ml={10}>
                        <DesktopNav />
                    </Flex>
                </Flex>
            </Flex>
            <Collapse in={isOpen} animateOpacity>
                <MobileNav />
            </Collapse>
        </Box>
    );
}

export default Navbar;
