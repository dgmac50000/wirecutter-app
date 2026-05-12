import React from 'react';
import { StyleSheet, ScrollView } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Headline, Body, spacing, colors } from '@/components/nyt-design-system';

export default function ProductDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Headline>Product Review</Headline>
      <Body style={styles.placeholder}>
        Detailed review for product #{id} will be rendered here.
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
