import React from 'react';
import { View, StyleSheet } from 'react-native';
import {
  Card,
  Subheadline,
  Body,
  Caption,
  Label,
  colors,
  spacing,
} from './nyt-design-system';
import { Review } from '@/services/types';

interface ReviewSummaryProps {
  review: Review;
}

export function ReviewSummary({ review }: ReviewSummaryProps) {
  return (
    <Card elevated>
      <Subheadline>{review.headline}</Subheadline>
      <Body style={styles.summary}>{review.summary}</Body>

      <View style={styles.section}>
        <Label color={colors.wirecutter.budget}>Pros</Label>
        {review.pros.map((pro, i) => (
          <Body key={i} style={styles.listItem}>
            + {pro}
          </Body>
        ))}
      </View>

      <View style={styles.section}>
        <Label color={colors.wirecutter.pick}>Cons</Label>
        {review.cons.map((con, i) => (
          <Body key={i} style={styles.listItem}>
            - {con}
          </Body>
        ))}
      </View>

      <View style={styles.verdict}>
        <Label>Verdict</Label>
        <Body>{review.verdict}</Body>
      </View>

      <Caption style={styles.meta}>
        By {review.author} | Updated {review.updatedAt}
      </Caption>
    </Card>
  );
}

const styles = StyleSheet.create({
  summary: {
    marginTop: spacing.sm,
    color: colors.secondary,
  },
  section: {
    marginTop: spacing.md,
  },
  listItem: {
    marginTop: spacing.xs,
    marginLeft: spacing.sm,
  },
  verdict: {
    marginTop: spacing.md,
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.surface,
  },
  meta: {
    marginTop: spacing.md,
  },
});
