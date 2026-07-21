import React from 'react';
import { StyleSheet, ScrollView, View, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import {
  Headline,
  Subheadline,
  Body,
  Caption,
  spacing,
  colors,
  radii,
} from '@/components/nyt-design-system';

const CATEGORIES = [
  {
    slug: 'home',
    name: 'Home',
    subcategories: ['Cleaning', 'Smart home devices', 'Bedroom'],
    color: '#4A90D9',
  },
  {
    slug: 'electronics',
    name: 'Electronics',
    subcategories: ['Smartphones', 'Audio', 'Computers'],
    color: '#7B68EE',
  },
  {
    slug: 'sleep',
    name: 'Sleep',
    subcategories: ['How to sleep better', 'Sleep gear', 'Mattresses'],
    color: '#6B5B95',
  },
  {
    slug: 'kitchen',
    name: 'Kitchen',
    subcategories: ['Cooking tools', 'Small appliances', 'Cookware'],
    color: '#E8672C',
  },
  {
    slug: 'appliances',
    name: 'Appliances',
    subcategories: ['Small appliances', 'Large appliances', 'Vacuums'],
    color: '#3D9970',
  },
  {
    slug: 'gifts',
    name: 'Gifts',
    subcategories: ['For grown-ups', 'Surprise Me', 'Special occasions'],
    color: '#E84393',
  },
  {
    slug: 'outdoors',
    name: 'Outdoors',
    subcategories: ['Outdoor gear', 'Apparel', 'Camping'],
    color: '#27AE60',
  },
  {
    slug: 'style',
    name: 'Style',
    subcategories: ['Women\'s', 'Men\'s', 'Accessories'],
    color: '#F39C12',
  },
  {
    slug: 'travel',
    name: 'Travel',
    subcategories: ['Gear', 'Bags', 'Luggage'],
    color: '#2980B9',
  },
];

export default function CategoriesScreen() {
  const router = useRouter();

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Headline>Categories</Headline>
      </View>

      {CATEGORIES.map((cat) => (
        <Pressable
          key={cat.slug}
          style={styles.categoryCard}
          onPress={() => router.push(`/category/${cat.slug}`)}
        >
          <View style={[styles.categoryIcon, { backgroundColor: cat.color }]}>
            <Subheadline style={styles.categoryInitial}>
              {cat.name[0]}
            </Subheadline>
          </View>
          <View style={styles.categoryContent}>
            <Subheadline>{cat.name}</Subheadline>
            <Caption>{cat.subcategories.join(' · ')}</Caption>
          </View>
        </Pressable>
      ))}
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
    marginBottom: spacing.lg,
  },
  categoryCard: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.surface,
  },
  categoryIcon: {
    width: 48,
    height: 48,
    borderRadius: radii.lg,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.md,
  },
  categoryInitial: {
    color: colors.background,
    fontWeight: '700',
  },
  categoryContent: {
    flex: 1,
  },
});
