import DesktopSubNav from './DesktopSubNav';
import NAV_ITEMS from '../NavItems';
import {
    Stack,
    Box,
    Popover,
    Link,
    PopoverTrigger,
    useColorModeValue,
    PopoverContent,
} from '@chakra-ui/react';

const DesktopNav = () => {
    const linkColor = useColorModeValue("gray.200", "gray.200");
    const linkHoverColor = useColorModeValue("gray.300", "white");
    const popoverContentBgColor = useColorModeValue("gray.700", "gray.800");

    return (
        <Stack direction={"row"} spacing={4}>
            {NAV_ITEMS.map((navItem) => (
                <Box key={navItem.label}>
                    <Popover trigger={"hover"} placement={"bottom-start"}>
                        <PopoverTrigger>
                            <Link
                                p={2}
                                textStyle={"h4"}
                                href={navItem.href ?? "#"}
                                color={linkColor}
                                _hover={{
                                    textDecoration: "none",
                                    color: linkHoverColor,
                                }}
                            >
                                {navItem.label}
                            </Link>
                        </PopoverTrigger>

                        {navItem.children && (
                            <PopoverContent
                                border={0}
                                boxShadow={"xl"}
                                bg={popoverContentBgColor}
                                p={4}
                                rounded={"xl"}
                                minW={"sm"}
                            >
                                <Stack>
                                    {navItem.children.map((child) => (
                                        <DesktopSubNav
                                            key={child.label}
                                            {...child}
                                        />
                                    ))}
                                </Stack>
                            </PopoverContent>
                        )}
                    </Popover>
                </Box>
            ))}
        </Stack>
    );
};

export default DesktopNav;