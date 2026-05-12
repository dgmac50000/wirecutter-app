import React from 'react';
import { StyleSheet, ScrollView } from 'react-native';
import { Headline, Body, spacing, colors } from '@/components/nyt-design-system';

export default function SearchScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Headline>Search</Headline>
      <Body style={styles.placeholder}>
        Search across all product reviews and recommendations.
      </Body>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  content: {
    padding: spacing.lg,
  },
  placeholder: {
    marginTop: spacing.md,
    color: colors.secondary,
  },
});
