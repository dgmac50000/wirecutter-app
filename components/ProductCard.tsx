import React from 'react';
import { View, Image, StyleSheet, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import {
  Card,
  Subheadline,
  Body,
  Caption,
  Label,
  colors,
  spacing,
} from './nyt-design-system';
import { Product } from '@/services/types';

interface ProductCardProps {
  product: Product;
}

const badgeLabels: Record<string, string> = {
  'top-pick': 'Our Pick',
  'budget-pick': 'Budget Pick',
  'upgrade-pick': 'Upgrade Pick',
};

const badgeColors: Record<string, string> = {
  'top-pick': colors.wirecutter.pick,
  'budget-pick': colors.wirecutter.budget,
  'upgrade-pick': colors.wirecutter.upgrade,
};

export function ProductCard({ product }: ProductCardProps) {
  const router = useRouter();

  return (
    <Pressable onPress={() => router.push(`/product/${product.id}`)}>
      <Card elevated padded={false}>
        {product.imageUrl && (
          <Image source={{ uri: product.imageUrl }} style={styles.image} />
        )}
        <View style={styles.content}>
          {product.badge && (
            <Label color={badgeColors[product.badge]}>
              {badgeLabels[product.badge]}
            </Label>
          )}
          <Subheadline style={styles.title}>{product.title}</Subheadline>
          <Body style={styles.subtitle}>{product.subtitle}</Body>
          {product.priceRange && (
            <Caption>{product.priceRange}</Caption>
          )}
        </View>
      </Card>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  image: {
    width: '100%',
    height: 200,
    resizeMode: 'cover',
  },
  content: {
    padding: spacing.md,
  },
  title: {
    marginTop: spacing.xs,
  },
  subtitle: {
    marginTop: spacing.xs,
    color: colors.secondary,
  },
});
