import React from 'react';
import { StyleSheet, ScrollView, View } from 'react-native';
import {
  Headline,
  Subheadline,
  Body,
  spacing,
  colors,
} from '@/components/nyt-design-system';

export default function HomeScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Headline>Wirecutter</Headline>
        <Body style={styles.tagline}>
          Real-world tested. Expert recommended.
        </Body>
      </View>

      <View style={styles.section}>
        <Subheadline>Top Picks</Subheadline>
        <Body style={styles.placeholder}>
          Our latest expert-tested product recommendations will appear here.
        </Body>
      </View>

      <View style={styles.section}>
        <Subheadline>New Reviews</Subheadline>
        <Body style={styles.placeholder}>
          Recently published reviews and guides.
        </Body>
      </View>
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
  header: {
    marginBottom: spacing.xl,
  },
  tagline: {
    marginTop: spacing.xs,
    color: colors.secondary,
  },
  section: {
    marginBottom: spacing.lg,
  },
  placeholder: {
    marginTop: spacing.sm,
    color: colors.secondary,
  },
});
