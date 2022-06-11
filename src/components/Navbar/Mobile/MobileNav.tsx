import NAV_ITEMS from '../NavItems';
import MobileNavItem from './MobileNavItem';
import {
    Stack,
    useColorModeValue,
} from "@chakra-ui/react";

const MobileNav = () => {
    return (
        <Stack
            bg={useColorModeValue("gray.800", "gray.800")}
            p={4}
            display={{ md: "none" }}
        >
            {NAV_ITEMS.map((navItem) => (
                <MobileNavItem key={navItem.label} {...navItem} />
            ))}
        </Stack>
    );
};

export default MobileNav;