import React from 'react';
import { StyleSheet, ScrollView } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Headline, Body, spacing, colors } from '@/components/nyt-design-system';

export default function CategoryListingScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Headline>{slug ?? 'Category'}</Headline>
      <Body style={styles.placeholder}>
        Products in this category will be listed here.
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
