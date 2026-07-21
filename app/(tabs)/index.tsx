import React from 'react';
import { StyleSheet, ScrollView, View, Image, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import {
  Headline,
  Subheadline,
  Body,
  Caption,
  Label,
  Card,
  spacing,
  colors,
} from '@/components/nyt-design-system';
import { ProductTile } from '@/components/ProductTile';

const FEATURED = {
  title: 'The Best Carry-On Luggage',
  subtitle: 'We tested 90+ bags over 10 years of travel.',
  imageUrl: 'https://images.unsplash.com/photo-1565026057447-bc90a3dceb87?w=600&q=80',
};

const TOP_PICKS = [
  {
    id: '1',
    name: 'Sony WF-1000XM5 Wireless Earbuds',
    imageUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12f8e568b?w=300&q=80',
    affiliateLinks: [
      { price: '$228', merchant: 'Amazon' },
      { price: '$230', merchant: 'Best Buy' },
    ],
  },
  {
    id: '2',
    name: 'Ninja AF101 Air Fryer',
    imageUrl: 'https://images.unsplash.com/photo-1648455702691-3c0ada3930c5?w=300&q=80',
    affiliateLinks: [
      { price: '$90', merchant: 'Amazon' },
    ],
  },
  {
    id: '3',
    name: 'Pendleton Block Plaid Organic Cotton Throw',
    imageUrl: 'https://images.unsplash.com/photo-1580301762395-21ce5da26ea9?w=300&q=80',
    affiliateLinks: [
      { price: '$98', merchant: 'Nordstrom' },
      { price: '$98', merchant: 'Pendleton' },
    ],
  },
  {
    id: '4',
    name: 'Hisense U75QG 85-Inch 4K TV',
    imageUrl: 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=300&q=80',
    affiliateLinks: [
      { price: '$1,200', merchant: 'Amazon' },
    ],
  },
];

const LATEST_ARTICLES = [
  {
    id: '1',
    title: 'The Best Wireless Bluetooth Earbuds',
    category: 'Electronics',
    badge: 'Our Pick',
  },
  {
    id: '2',
    title: 'The Best Dishwashers',
    category: 'Appliances',
    badge: 'Our Pick',
  },
  {
    id: '3',
    title: 'The Best Waterproof Tough Camera',
    category: 'Electronics',
    badge: 'Our Pick',
  },
  {
    id: '4',
    title: 'Our Very Favorite Grilling Tools',
    category: 'Kitchen',
    badge: 'Our Pick',
  },
  {
    id: '5',
    title: 'The Best Chromebook',
    category: 'Electronics',
    badge: 'Budget Pick',
  },
];

export default function PicksScreen() {
  const router = useRouter();

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Headline>Wirecutter</Headline>
        <Caption>Real-world tested. Expert recommended.</Caption>
      </View>

      <Pressable style={styles.featured}>
        <Card elevated padded={false}>
          <Image
            source={{ uri: FEATURED.imageUrl }}
            style={styles.featuredImage}
          />
          <View style={styles.featuredContent}>
            <Label color={colors.wirecutter.pick}>Featured</Label>
            <Subheadline style={styles.featuredTitle}>
              {FEATURED.title}
            </Subheadline>
            <Body style={styles.featuredSubtitle}>{FEATURED.subtitle}</Body>
          </View>
        </Card>
      </Pressable>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Subheadline>Top Picks</Subheadline>
          <Pressable>
            <Caption color={colors.wirecutter.blue}>See all</Caption>
          </Pressable>
        </View>

        {TOP_PICKS.map((product) => (
          <View key={product.id} style={styles.tileWrapper}>
            <ProductTile
              name={product.name}
              imageUrl={product.imageUrl}
              affiliateLinks={product.affiliateLinks}
              onPress={() => router.push(`/product/${product.id}`)}
            />
          </View>
        ))}
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Subheadline>The Latest</Subheadline>
          <Pressable>
            <Caption color={colors.wirecutter.blue}>See all</Caption>
          </Pressable>
        </View>

        {LATEST_ARTICLES.map((article) => (
          <Pressable
            key={article.id}
            style={styles.articleRow}
            onPress={() => router.push(`/product/${article.id}`)}
          >
            <View style={styles.articleContent}>
              <Label
                color={
                  article.badge === 'Budget Pick'
                    ? colors.wirecutter.budget
                    : colors.wirecutter.pick
                }
              >
                {article.badge}
              </Label>
              <Body style={styles.articleTitle}>{article.title}</Body>
              <Caption>{article.category}</Caption>
            </View>
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
    paddingBottom: spacing.xl,
  },
  header: {
    padding: 20,
    paddingBottom: spacing.md,
  },
  featured: {
    paddingHorizontal: 20,
    marginBottom: spacing.lg,
  },
  featuredImage: {
    height: 200,
    width: '100%',
    resizeMode: 'cover',
  },
  featuredContent: {
    padding: spacing.md,
  },
  featuredTitle: {
    marginTop: spacing.xs,
  },
  featuredSubtitle: {
    marginTop: spacing.xs,
    color: colors.secondary,
  },
  section: {
    paddingHorizontal: 20,
    marginBottom: spacing.lg,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  tileWrapper: {
    marginBottom: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#EEEEEE',
  },
  articleRow: {
    flexDirection: 'row',
    marginBottom: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#EEEEEE',
  },
  articleContent: {
    flex: 1,
  },
  articleTitle: {
    marginVertical: 2,
    fontWeight: '600',
  },
});
