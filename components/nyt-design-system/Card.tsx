import React from 'react';
import { View, ViewProps, StyleSheet } from 'react-native';
import { colors, spacing, radii, shadows } from './tokens';

interface CardProps extends ViewProps {
  elevated?: boolean;
  padded?: boolean;
}

export function Card({
  elevated = true,
  padded = true,
  style,
  children,
  ...props
}: CardProps) {
  return (
    <View
      style={[
        styles.base,
        padded && styles.padded,
        elevated && shadows.md,
        style,
      ]}
      {...props}
    >
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    backgroundColor: colors.background,
    borderRadius: radii.lg,
    overflow: 'hidden',
  },
  padded: {
    padding: spacing.md,
  },
});
