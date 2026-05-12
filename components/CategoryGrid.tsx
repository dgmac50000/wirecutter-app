import React from 'react';
import { View, FlatList, Image, StyleSheet, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import { Body, Caption, Card, colors, spacing } from './nyt-design-system';
import { Category } from '@/services/types';

interface CategoryGridProps {
  categories: Category[];
}

export function CategoryGrid({ categories }: CategoryGridProps) {
  const router = useRouter();

  return (
    <FlatList
      data={categories}
      numColumns={2}
      columnWrapperStyle={styles.row}
      keyExtractor={(item) => item.slug}
      renderItem={({ item }) => (
        <Pressable
          style={styles.item}
          onPress={() => router.push(`/category/${item.slug}`)}
        >
          <Card elevated padded={false}>
            {item.imageUrl && (
              <Image source={{ uri: item.imageUrl }} style={styles.image} />
            )}
            <View style={styles.content}>
              <Body>{item.name}</Body>
              <Caption>{item.productCount} picks</Caption>
            </View>
          </Card>
        </Pressable>
      )}
    />
  );
}

const styles = StyleSheet.create({
  row: {
    justifyContent: 'space-between',
    marginBottom: spacing.md,
  },
  item: {
    flex: 1,
    marginHorizontal: spacing.xs,
  },
  image: {
    width: '100%',
    height: 100,
    resizeMode: 'cover',
  },
  content: {
    padding: spacing.sm,
  },
});
