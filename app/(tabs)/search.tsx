import React, { useState } from 'react';
import { StyleSheet, ScrollView, View, TextInput, Pressable } from 'react-native';
import {
  Headline,
  Body,
  Caption,
  Label,
  spacing,
  colors,
  radii,
} from '@/components/nyt-design-system';

const TRENDING = [
  'Best earbuds',
  'Air purifier',
  'Standing desk',
  'Portable charger',
  'Robot vacuum',
  'Carry-on luggage',
  'Mattress',
  'Wireless headphones',
];

const RECENT_REVIEWS = [
  'The Best Wireless Bluetooth Earbuds',
  'The Best Dishwashers',
  'The Best Carry-On Luggage',
  'Our Very Favorite Grilling Tools',
];

export default function SearchScreen() {
  const [query, setQuery] = useState('');

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Headline>Search</Headline>
      </View>

      <View style={styles.searchBar}>
        <TextInput
          style={styles.input}
          placeholder="What are you looking for?"
          placeholderTextColor={colors.secondary}
          value={query}
          onChangeText={setQuery}
        />
      </View>

      <View style={styles.section}>
        <Label style={styles.sectionLabel}>Trending</Label>
        <View style={styles.chipGrid}>
          {TRENDING.map((term) => (
            <Pressable
              key={term}
              style={styles.chip}
              onPress={() => setQuery(term)}
            >
              <Caption style={styles.chipText}>{term}</Caption>
            </Pressable>
          ))}
        </View>
      </View>

      <View style={styles.section}>
        <Label style={styles.sectionLabel}>Popular Reviews</Label>
        {RECENT_REVIEWS.map((review) => (
          <Pressable key={review} style={styles.recentRow}>
            <Body>{review}</Body>
          </Pressable>
        ))}
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
    paddingBottom: spacing.xl,
  },
  header: {
    marginBottom: spacing.md,
  },
  searchBar: {
    marginBottom: spacing.lg,
  },
  input: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm + 4,
    fontSize: 16,
    color: colors.primary,
  },
  section: {
    marginBottom: spacing.lg,
  },
  sectionLabel: {
    marginBottom: spacing.sm,
  },
  chipGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  chip: {
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radii.full,
  },
  chipText: {
    color: colors.primary,
  },
  recentRow: {
    paddingVertical: spacing.sm + 2,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.surface,
  },
});
