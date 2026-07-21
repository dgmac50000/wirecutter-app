import React from 'react';
import { View, Image, StyleSheet, Pressable, ScrollView } from 'react-native';
import { Body, Caption, colors, spacing } from './nyt-design-system';

interface AffiliateLink {
  price: string;
  merchant: string;
  url?: string;
}

interface ProductQuickViewProps {
  title: string;
  subtitle?: string;
  imageUrl?: string;
  productName: string;
  affiliateLinks: AffiliateLink[];
  description?: string;
  onClose?: () => void;
  onCtaPress?: () => void;
}

export function ProductQuickView({
  title,
  subtitle,
  imageUrl,
  productName,
  affiliateLinks,
  description,
  onClose,
  onCtaPress,
}: ProductQuickViewProps) {
  return (
    <View style={styles.container}>
      <View style={styles.handleBar} />

      <View style={styles.header}>
        <View style={styles.headerText}>
          <Caption style={styles.quickViewLabel}>Quick view</Caption>
          <Body style={styles.headerTitle}>{title}</Body>
        </View>
        <Pressable style={styles.closeButton} onPress={onClose}>
          <Body style={styles.closeIcon}>{'\u203A'}</Body>
        </Pressable>
      </View>

      <ScrollView
        style={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {imageUrl && (
          <Image source={{ uri: imageUrl }} style={styles.heroImage} />
        )}
        {!imageUrl && <View style={styles.heroImagePlaceholder} />}

        <View style={styles.productTile}>
          <View style={styles.tileImage} />
          <View style={styles.tileInfo}>
            <Body style={styles.productName} numberOfLines={2}>
              {productName}
            </Body>
            <View style={styles.links}>
              {affiliateLinks.map((link, i) => (
                <Caption key={i} style={styles.linkText}>
                  {link.price} from {link.merchant}
                </Caption>
              ))}
            </View>
          </View>
        </View>

        {description && (
          <Body style={styles.description}>{description}</Body>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    flex: 1,
    overflow: 'hidden',
  },
  handleBar: {
    width: 40,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#CCCCCC',
    alignSelf: 'center',
    marginTop: spacing.sm,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingTop: 24,
    paddingBottom: 16,
  },
  headerText: {
    flex: 1,
  },
  quickViewLabel: {
    fontWeight: '500',
    fontSize: 14,
    lineHeight: 20,
    color: '#000000',
  },
  headerTitle: {
    fontWeight: '800',
    fontSize: 22,
    lineHeight: 24,
    letterSpacing: -0.5,
    color: '#000000',
  },
  closeButton: {
    width: 38,
    height: 38,
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeIcon: {
    fontSize: 28,
    color: '#000000',
    transform: [{ rotate: '180deg' }],
  },
  scrollContent: {
    flex: 1,
  },
  heroImage: {
    width: 335,
    height: 335,
    alignSelf: 'center',
    resizeMode: 'cover',
  },
  heroImagePlaceholder: {
    width: 335,
    height: 335,
    alignSelf: 'center',
    backgroundColor: colors.surface,
  },
  productTile: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    paddingHorizontal: 19,
    paddingVertical: spacing.md,
  },
  tileImage: {
    width: 109,
    height: 100,
    backgroundColor: colors.surface,
  },
  tileInfo: {
    flex: 1,
    gap: spacing.sm,
  },
  productName: {
    fontWeight: '700',
    fontSize: 16,
    lineHeight: 21,
    letterSpacing: -0.5,
    color: '#000000',
  },
  links: {
    gap: 2,
  },
  linkText: {
    fontWeight: '500',
    fontSize: 14,
    lineHeight: 16,
    color: '#000000',
    textDecorationLine: 'underline',
  },
  description: {
    fontFamily: 'NYTImperial',
    fontSize: 18,
    lineHeight: 30,
    color: '#000000',
    paddingHorizontal: 20,
    paddingTop: spacing.md,
  },
});
