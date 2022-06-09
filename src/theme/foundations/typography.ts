const FONT_WEIGHT = {
    MEDIUM: 'medium',
    SEMIBOLD: 'semibold',
    BOLD: 'bold',
}

const textStyles = {
    display: {
        fontSize: '7xl',
        fontWeight: FONT_WEIGHT.BOLD,
        lineHeight: 'tall',
    },
    h1: {
        fontSize: '6xl',
        fontWeight: FONT_WEIGHT.BOLD,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
    h2: {
        fontSize: '4xl',
        fontWeight: FONT_WEIGHT.BOLD,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
    h3: {
        fontSize: '2xl',
        fontWeight: FONT_WEIGHT.SEMIBOLD,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
    h4: {
        fontSize: 'xl',
        fontWeight: FONT_WEIGHT.SEMIBOLD,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
    body_base: {
        fontSize: 'md',
        fontWeight: FONT_WEIGHT.MEDIUM,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
    body_sm: {
        fontSize: 'sm',
        fontWeight: FONT_WEIGHT.MEDIUM,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
    body_label: {
        fontSize: 'xs',
        fontWeight: FONT_WEIGHT.SEMIBOLD,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
    body_instruction: {
        fontSize: 'xs',
        fontWeight: FONT_WEIGHT.MEDIUM,
        lineHeight: 'normal',
        letterSpacing: 'tighter',
    },
}

export type TextStyles = typeof textStyles;

export default textStyles;