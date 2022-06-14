import { 
    extendTheme,
    theme as base,
    withDefaultColorScheme,
    withDefaultVariant
} from '@chakra-ui/react';
import fonts from './foundations/fonts';
import textStyles from './foundations/typography';
import colors from './foundations/colors';
import { Button, FormLabel, Text } from '../components/OpenLoan/OpenLoanStyle'

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
                bg: "gray.800"
            }
        })
    },
    components: {
        Button,
        FormLabel,
        Text
    },
})

export default theme