import { 
    extendTheme,
    theme as base,
    withDefaultColorScheme,
    withDefaultVariant
} from '@chakra-ui/react';
import fonts from './foundations/fonts';
import textStyles from './foundations/typography';
import colors from './foundations/colors';

const theme = extendTheme({
    colors: {
        ...colors
    },
    fonts: {
        ...fonts
    },
    layerStyles: {
        
    },
    textStyles: {
        ...textStyles
    },
    styles: {
        global: () => ({
            body: {
                bg: "#FFF",
            }
        })
    },
})

export default theme