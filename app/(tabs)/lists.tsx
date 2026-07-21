import React from 'react';
import { StyleSheet, ScrollView, View, Pressable } from 'react-native';
import {
  Headline,
  Subheadline,
  Body,
  Caption,
  Card,
  spacing,
  colors,
} from '@/components/nyt-design-system';

const LISTS = [
  {
    id: '1',
    title: 'The Best Travel Gear and Accessories',
    count: 24,
    category: 'Travel',
  },
  {
    id: '2',
    title: '16 Activities for Younger Kids That Make Screen-Free Travel Possible',
    count: 16,
    category: 'Kids',
  },
  {
    id: '3',
    title: 'The Best Gear for Your Road Trips',
    count: 18,
    category: 'Travel',
  },
  {
    id: '4',
    title: '7 Cheap(ish) Things to Improve Your In-Flight Experience',
    count: 7,
    category: 'Travel',
  },
  {
    id: '5',
    title: 'The 60 Best Gifts for Frequent Travelers',
    count: 60,
    category: 'Gifts',
  },
  {
    id: '6',
    title: '13 Gifts for Stationery Lovers',
    count: 13,
    category: 'Gifts',
  },
  {
    id: '7',
    title: 'The Best Electronics Kits for Kids and Beginners',
    count: 12,
    category: 'Electronics',
  },
  {
    id: '8',
    title: 'Find Your Perfect Swimsuit',
    count: 20,
    category: 'Style',
  },
];

export default function ListsScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Headline>Lists</Headline>
        <Caption>Curated collections from our experts</Caption>
      </View>

      {LISTS.map((list) => (
        <Pressable key={list.id}>
          <Card style={styles.listCard} elevated>
            <View style={styles.listRow}>
              <View style={styles.listImage} />
              <View style={styles.listContent}>
                <Caption>{list.category}</Caption>
                <Body style={styles.listTitle}>{list.title}</Body>
                <Caption>{list.count} items</Caption>
              </View>
            </View>
          </Card>
        </Pressable>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.surface,
  },
  content: {
    padding: spacing.lg,
    paddingBottom: spacing.xl,
  },
  header: {
    marginBottom: spacing.lg,
  },
  listCard: {
    marginBottom: spacing.md,
  },
  listRow: {
    flexDirection: 'row',
  },
  listImage: {
    width: 100,
    height: 100,
    borderRadius: 8,
    backgroundColor: colors.surface,
    marginRight: spacing.md,
  },
  listContent: {
    flex: 1,
    justifyContent: 'center',
  },
  listTitle: {
    fontWeight: '600',
    marginVertical: spacing.xs,
  },
});
