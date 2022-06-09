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
        lineHeight: 'tall',
    },
    h2: {
        fontSize: '4xl',
        fontWeight: FONT_WEIGHT.BOLD,
        lineHeight: 'tall',
    },
    h3: {
        fontSize: '2xl',
        fontWeight: FONT_WEIGHT.SEMIBOLD,
        lineHeight: 'tall',
    },
    h4: {
        fontSize: 'xl',
        fontWeight: FONT_WEIGHT.SEMIBOLD,
        lineHeight: 'tall',
    },
    body_base: {
        fontSize: 'md',
        fontWeight: FONT_WEIGHT.MEDIUM,
        lineHeight: 'tall',
    },
    body_sm: {
        fontSize: 'sm',
        fontWeight: FONT_WEIGHT.MEDIUM,
        lineHeight: 'tall',
    },
    body_label: {
        fontSize: 'xs',
        fontWeight: FONT_WEIGHT.SEMIBOLD,
        lineHeight: 'tall',
    },
    body_instruction: {
        fontSize: 'xs',
        fontWeight: FONT_WEIGHT.MEDIUM,
        lineHeight: 'tall',
    },
}

export type TextStyles = typeof textStyles;

export default textStyles;