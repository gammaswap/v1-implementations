type NavItems = {
    label: string,
    href: string;
}

const NavItems: Array<NavItems> = [
    {
        label: 'Logo',
        href: '#',
    },
    {
        label: 'Blog',
        href: 'https://medium.com/@danielalcarraz_42353',
    },
    {
        label: 'About Us',
        href: '/aboutus'
    }
    // {
    //     label: 'Home',
    //     href: '/',
    // },
    // {
    //     label: 'About',
    //     href: '/about',
    // },
    // {
    //     label: 'Launch',
    //     href: '/app',
    // },
    // {
    //     label: 'Need crypto?',
    //     href: '/transak',
    // },
    // {
    //     label: 'Bridge',
    //     href: '/bridge',
    // },
];

export default NavItems