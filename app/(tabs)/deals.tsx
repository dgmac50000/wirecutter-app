import React, { useCallback, useRef, useState } from 'react';
import { StyleSheet, ScrollView, View, Modal, Pressable } from 'react-native';
import { Headline, Caption, Body, spacing, colors } from '@/components/nyt-design-system';
import { DealCard } from '@/components/DealCard';
import { ProductQuickView } from '@/components/ProductQuickView';

const DEALS = [
  {
    id: '1',
    headline: 'The best all-around air fryer',
    images: [
      'https://images.unsplash.com/photo-1648455702691-3c0ada3930c5?w=400&q=80',
    ],
    productLabel: 'Ninja Air Fryer Pro',
    productName: 'Ninja AF101 Air Fryer',
    pros: [
      'Cooks food quickly and evenly',
      'Uses less oil for healthier meals',
      'Easy to clean with dishwasher-safe parts',
      'Saves energy compared to traditional ovens',
    ],
    cons: [
      'Can be bulky and take up counter space',
      'Some models are noisy during operation',
      'May not achieve the same crispiness as deep frying',
    ],
    ctaText: '$90 from Amazon',
    affiliateLinks: [
      { price: '$90', merchant: 'Amazon' },
      { price: '$95', merchant: 'Walmart' },
    ],
    description:
      'After testing 10 air fryers over the past two years, we think the Ninja AF101 is the best for most people. It heats up quickly, cooks food evenly, and is easy to clean.',
  },
  {
    id: '2',
    headline: 'A lightweight throw for every season',
    images: [
      'https://images.unsplash.com/photo-1580301762395-21ce5da26ea9?w=400&q=80',
    ],
    productLabel: 'Pendleton Block Plaid',
    productName: 'Pendleton Block Plaid Organic Cotton Fringed Throw',
    pros: [
      'Exceptionally soft organic cotton',
      'Machine washable and dryable',
      'Beautiful block plaid pattern in three colors',
      'Feather-soft eyelash fringe',
    ],
    cons: [
      'Less warm than wool alternatives',
      'Limited color options',
    ],
    ctaText: '$98 from Nordstrom',
    affiliateLinks: [
      { price: '$98', merchant: 'Nordstrom' },
      { price: '$98', merchant: 'Pendleton' },
    ],
    description:
      'A classic Pendleton wool blanket can set you back as much as $500. Fortunately, these Pendleton Block Plaid Organic Cotton Fringed Throws are even better. They\'re made with layers of exceptionally soft cotton.',
  },
  {
    id: '3',
    headline: 'The best wireless earbuds for most people',
    images: [
      'https://images.unsplash.com/photo-1590658268037-6bf12f8e568b?w=400&q=80',
    ],
    productLabel: 'Sony WF-1000XM5',
    productName: 'Sony WF-1000XM5 Wireless Earbuds',
    pros: [
      'Outstanding active noise cancellation',
      'Excellent sound quality with LDAC support',
      'Comfortable for extended listening sessions',
      'Strong battery life (8h buds, 24h with case)',
    ],
    cons: [
      'Premium price point at $228',
      'Touch controls can be finicky in rain',
      'No multipoint connection by default',
    ],
    ctaText: '$228 from Amazon',
    affiliateLinks: [
      { price: '$228', merchant: 'Amazon' },
      { price: '$230', merchant: 'Best Buy' },
    ],
    description:
      'After testing over 500 pairs of wireless earbuds, the Sony WF-1000XM5 remains our top pick. The noise cancellation is class-leading, and the sound quality satisfies even critical listeners.',
  },
];

export default function DealsScreen() {
  const [quickViewDeal, setQuickViewDeal] = useState<(typeof DEALS)[0] | null>(
    null
  );

  return (
    <View style={styles.wrapper}>
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.content}
      >
        <View style={styles.header}>
          <Headline>Daily Deals</Headline>
          <Caption>134 deals today</Caption>
        </View>

        {DEALS.map((deal) => (
          <Pressable
            key={deal.id}
            style={styles.cardWrapper}
            onPress={() => setQuickViewDeal(deal)}
          >
            <DealCard
              headline={deal.headline}
              images={deal.images}
              productLabel={deal.productLabel}
              pros={deal.pros}
              cons={deal.cons}
              ctaText={deal.ctaText}
            />
          </Pressable>
        ))}
      </ScrollView>

      <Modal
        visible={quickViewDeal !== null}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setQuickViewDeal(null)}
      >
        {quickViewDeal && (
          <ProductQuickView
            title={quickViewDeal.productLabel}
            imageUrl={quickViewDeal.images[0]}
            productName={quickViewDeal.productName}
            affiliateLinks={quickViewDeal.affiliateLinks}
            description={quickViewDeal.description}
            onClose={() => setQuickViewDeal(null)}
          />
        )}
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    flex: 1,
  },
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  content: {
    padding: 20,
    paddingBottom: spacing.xl,
  },
  header: {
    marginBottom: spacing.lg,
  },
  cardWrapper: {
    marginBottom: spacing.xl,
    paddingBottom: spacing.xl,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#EEEEEE',
  },
});
