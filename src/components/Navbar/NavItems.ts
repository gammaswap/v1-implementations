interface NavItem {
    label: string;
    subLabel?: string;
    children?: Array<NavItem>;
    href?: string;
}

const NAV_ITEMS: Array<NavItem> = [
    {
        label: "Blog",
        href: "https://medium.com/gammaswap-labs",
    },
    {
        label: "About Us",
        href: "#",
    },
];

export type navItem = NavItem;

export default NAV_ITEMS;