import React from 'react';
import { View, Image, StyleSheet, Pressable } from 'react-native';
import { Body, Caption, colors, spacing } from './nyt-design-system';

interface AffiliateLink {
  price: string;
  merchant: string;
  url?: string;
}

interface ProductTileProps {
  imageUrl?: string;
  name: string;
  affiliateLinks: AffiliateLink[];
  onPress?: () => void;
}

export function ProductTile({
  imageUrl,
  name,
  affiliateLinks,
  onPress,
}: ProductTileProps) {
  return (
    <Pressable style={styles.container} onPress={onPress}>
      <View style={styles.imageWrapper}>
        {imageUrl ? (
          <Image source={{ uri: imageUrl }} style={styles.image} />
        ) : (
          <View style={styles.imagePlaceholder} />
        )}
      </View>

      <View style={styles.info}>
        <Body style={styles.name} numberOfLines={2}>
          {name}
        </Body>
        <View style={styles.links}>
          {affiliateLinks.map((link, i) => (
            <Caption key={i} style={styles.linkText}>
              {link.price} from {link.merchant}
            </Caption>
          ))}
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  imageWrapper: {
    width: 109,
    height: 100,
    borderRadius: 0,
    overflow: 'hidden',
  },
  image: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  imagePlaceholder: {
    width: '100%',
    height: '100%',
    backgroundColor: colors.surface,
  },
  info: {
    flex: 1,
    gap: spacing.sm,
  },
  name: {
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
});
