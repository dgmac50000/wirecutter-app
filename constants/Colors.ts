import { colors } from '@/components/nyt-design-system/tokens';

export default {
  light: {
    text: colors.primary,
    background: colors.background,
    tint: colors.accent,
    tabIconDefault: colors.secondary,
    tabIconSelected: colors.accent,
  },
  dark: {
    text: colors.background,
    background: colors.primary,
    tint: colors.wirecutter.blue,
    tabIconDefault: '#9BA1A6',
    tabIconSelected: colors.wirecutter.blue,
  },
};
