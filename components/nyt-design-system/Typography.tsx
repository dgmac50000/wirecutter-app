import React from 'react';
import { Text, TextProps, StyleSheet } from 'react-native';
import { typography, colors } from './tokens';

interface TypographyProps extends TextProps {
  color?: string;
}

export function Headline({ style, color, ...props }: TypographyProps) {
  return (
    <Text
      style={[styles.headline, color ? { color } : undefined, style]}
      {...props}
    />
  );
}

export function Subheadline({ style, color, ...props }: TypographyProps) {
  return (
    <Text
      style={[styles.subheadline, color ? { color } : undefined, style]}
      {...props}
    />
  );
}

export function Body({ style, color, ...props }: TypographyProps) {
  return (
    <Text
      style={[styles.body, color ? { color } : undefined, style]}
      {...props}
    />
  );
}

export function Caption({ style, color, ...props }: TypographyProps) {
  return (
    <Text
      style={[styles.caption, color ? { color } : undefined, style]}
      {...props}
    />
  );
}

export function Label({ style, color, ...props }: TypographyProps) {
  return (
    <Text
      style={[styles.label, color ? { color } : undefined, style]}
      {...props}
    />
  );
}

const styles = StyleSheet.create({
  headline: {
    fontFamily: typography.families.serif,
    fontSize: typography.sizes.xxl,
    fontWeight: typography.weights.bold,
    lineHeight: typography.sizes.xxl * typography.lineHeights.tight,
    color: colors.primary,
  },
  subheadline: {
    fontFamily: typography.families.serif,
    fontSize: typography.sizes.xl,
    fontWeight: typography.weights.semibold,
    lineHeight: typography.sizes.xl * typography.lineHeights.tight,
    color: colors.primary,
  },
  body: {
    fontFamily: typography.families.sans,
    fontSize: typography.sizes.md,
    fontWeight: typography.weights.regular,
    lineHeight: typography.sizes.md * typography.lineHeights.normal,
    color: colors.primary,
  },
  caption: {
    fontFamily: typography.families.sans,
    fontSize: typography.sizes.sm,
    fontWeight: typography.weights.regular,
    lineHeight: typography.sizes.sm * typography.lineHeights.normal,
    color: colors.secondary,
  },
  label: {
    fontFamily: typography.families.sans,
    fontSize: typography.sizes.xs,
    fontWeight: typography.weights.medium,
    lineHeight: typography.sizes.xs * typography.lineHeights.normal,
    color: colors.secondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
});
