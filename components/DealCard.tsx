import React, { useState } from 'react';
import {
  View,
  Image,
  StyleSheet,
  Pressable,
  ScrollView,
  Dimensions,
} from 'react-native';
import { Body, Caption, colors, spacing, radii } from './nyt-design-system';

interface DealCardProps {
  headline: string;
  images: string[];
  productLabel?: string;
  pros: string[];
  cons: string[];
  ctaText: string;
  ctaUrl?: string;
  onCtaPress?: () => void;
}

export function DealCard({
  headline,
  images,
  productLabel,
  pros,
  cons,
  ctaText,
  onCtaPress,
}: DealCardProps) {
  const [activeIndex, setActiveIndex] = useState(0);

  return (
    <View style={styles.container}>
      <Body style={styles.headline}>{headline}</Body>

      <View style={styles.imageContainer}>
        <ScrollView
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          onMomentumScrollEnd={(e) => {
            const index = Math.round(
              e.nativeEvent.contentOffset.x / IMAGE_SIZE
            );
            setActiveIndex(index);
          }}
        >
          {images.map((uri, i) => (
            <Image key={i} source={{ uri }} style={styles.image} />
          ))}
          {images.length === 0 && <View style={styles.imagePlaceholder} />}
        </ScrollView>

        {productLabel && (
          <View style={styles.productBadge}>
            <Caption style={styles.productBadgeText}>{productLabel}</Caption>
          </View>
        )}

        {images.length > 1 && (
          <View style={styles.dots}>
            {images.map((_, i) => (
              <View
                key={i}
                style={[
                  styles.dot,
                  i === activeIndex ? styles.dotActive : styles.dotInactive,
                ]}
              />
            ))}
          </View>
        )}
      </View>

      <View style={styles.section}>
        <Body style={styles.sectionTitle}>Pros</Body>
        {pros.map((pro, i) => (
          <View key={i} style={styles.listItem}>
            <Body style={styles.bullet}>{'\u2022'}</Body>
            <Caption style={styles.listText}>{pro}</Caption>
          </View>
        ))}
      </View>

      <View style={styles.section}>
        <Body style={styles.sectionTitle}>Cons</Body>
        {cons.map((con, i) => (
          <View key={i} style={styles.listItem}>
            <Body style={styles.bullet}>{'\u2022'}</Body>
            <Caption style={styles.listText}>{con}</Caption>
          </View>
        ))}
      </View>

      <Pressable
        style={({ pressed }) => [
          styles.ctaButton,
          pressed && styles.ctaPressed,
        ]}
        onPress={onCtaPress}
      >
        <Body style={styles.ctaText}>{ctaText}</Body>
      </Pressable>
    </View>
  );
}

const IMAGE_SIZE = 335;

const styles = StyleSheet.create({
  container: {
    width: IMAGE_SIZE,
    gap: spacing.sm + 4,
  },
  headline: {
    fontFamily: 'NYTFranklin',
    fontSize: 24,
    fontWeight: '700',
    lineHeight: 30,
    letterSpacing: -0.25,
    color: '#000000',
  },
  imageContainer: {
    width: IMAGE_SIZE,
    height: IMAGE_SIZE,
    borderRadius: 5,
    overflow: 'hidden',
    backgroundColor: colors.surface,
  },
  image: {
    width: IMAGE_SIZE,
    height: IMAGE_SIZE,
    resizeMode: 'cover',
  },
  imagePlaceholder: {
    width: IMAGE_SIZE,
    height: IMAGE_SIZE,
    backgroundColor: colors.surface,
  },
  productBadge: {
    position: 'absolute',
    top: spacing.sm + 4,
    left: spacing.sm + 4,
    backgroundColor: '#E3F8FE',
    borderRadius: 5,
    paddingHorizontal: 6,
    paddingVertical: 4,
  },
  productBadgeText: {
    fontWeight: '500',
    fontSize: 14,
    lineHeight: 20,
    color: '#000000',
  },
  dots: {
    position: 'absolute',
    bottom: spacing.sm + 2,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 4,
  },
  dot: {
    borderRadius: 99,
  },
  dotActive: {
    width: 8,
    height: 8,
    backgroundColor: '#000000',
  },
  dotInactive: {
    width: 5,
    height: 5,
    backgroundColor: '#CCCCCC',
  },
  section: {
    gap: 4,
  },
  sectionTitle: {
    fontWeight: '700',
    fontSize: 16,
    lineHeight: 20,
    letterSpacing: -0.25,
    color: '#000000',
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingLeft: spacing.sm,
    gap: spacing.sm,
  },
  bullet: {
    fontSize: 14,
    lineHeight: 20,
    color: '#000000',
  },
  listText: {
    flex: 1,
    fontWeight: '500',
    fontSize: 14,
    lineHeight: 20,
    color: '#000000',
  },
  ctaButton: {
    backgroundColor: '#000000',
    borderWidth: 1,
    borderColor: '#000000',
    borderRadius: 4,
    paddingVertical: 9,
    paddingHorizontal: 16,
    alignItems: 'center',
    justifyContent: 'center',
    height: 40,
  },
  ctaPressed: {
    opacity: 0.8,
  },
  ctaText: {
    fontWeight: '700',
    fontSize: 16,
    lineHeight: 22,
    color: '#FFFFFF',
    textAlign: 'center',
  },
});
