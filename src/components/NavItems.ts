type NavItems = {
    label: string,
    href: string,
    target: string
}

const NavItems: Array<NavItems> = [
    {
        label: 'Logo',
        href: '#',
        target: ''
    },
    {
        label: 'Blog',
        href: 'https://medium.com/@danielalcarraz_42353',
        target: '_blank'
    },
    {
        label: 'About Us',
        href: '/aboutus',
        target: ''
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