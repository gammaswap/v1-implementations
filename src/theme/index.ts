import { 
    extendTheme,
    theme as base,
    withDefaultColorScheme,
    withDefaultVariant
} from '@chakra-ui/react';
import TextStyles from './foundations/typography';

const theme = extendTheme({
    colors: {
        brand: {
            primary: '#5631F1',
            secondary: '#172F5E',
            tertiary: '#936DFF',
            quaternary: '#DBD5F6',
            quinary: '#9AA3C7',
            firstaccent: '#FF6663',
            secondaccent: '#69DC9E',
        }
    },
    fonts: {
        heading: `Inter, sans-serif`,
        body: `Inter, sans-serif`,
    },
    layerStyles: {
        
    },
    textStyles: {
        ...TextStyles
    },
    styles: {
        global: () => ({
            body: {
                bg: "#0f172a",
            }
        })
    },
})

export default theme