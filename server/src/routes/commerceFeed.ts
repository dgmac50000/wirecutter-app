import { Router, Request, Response } from "express";
import { getProductCards, getScoopProductCards } from "../graphql/minotaurClient.js";
import type { MinotaurProductCard, MinotaurSource } from "../types/minotaur.js";
import type { CommerceItem, CommerceSource, CommerceFeedResponse } from "../types/commerce.js";
import { preferHiResImages } from "../utils/preferHiResImages.js";

const router = Router();

/**
 * GET /wirecutter/commerce-feed
 *
 * Query params:
 *   postIds  — comma-separated list of Yeti post IDs (optional, defaults to recent reviews)
 *   type     — "review" | "scoop" (default: "review")
 */
router.get("/wirecutter/commerce-feed", async (req: Request, res: Response) => {
  try {
    const type = (req.query.type as string) ?? "review";
    const postIdsParam = req.query.postIds as string | undefined;

    let postIds: number[];
    if (postIdsParam) {
      postIds = postIdsParam.split(",").map(Number).filter(Boolean);
    } else {
      postIds = await fetchRecentReviewPostIds();
    }

    if (postIds.length === 0) {
      res.json({ items: [] } satisfies CommerceFeedResponse);
      return;
    }

    let cards: MinotaurProductCard[];
    if (type === "scoop") {
      cards = await getScoopProductCards(postIds);
    } else {
      cards = await getProductCards(postIds);
    }

    const items = cards
      .map(normalizeProductCard)
      .filter((item): item is CommerceItem => item !== null);

    res.json({ items } satisfies CommerceFeedResponse);
  } catch (error) {
    console.error("[commerce-feed] Error:", error);
    res.status(500).json({
      error: "Failed to fetch commerce feed",
      message: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

function normalizeProductCard(card: MinotaurProductCard): CommerceItem | null {
  const article = card.article;
  if (!article) return null;

  const product = card.product;
  const sources: CommerceSource[] = (product?.sources ?? []).map(normalizeSource);

  return {
    articleId: article.postId,
    articleTitle: article.title,
    articleUrl: article.link,
    productId: card.productId,
    productTitle: product?.name ?? card.title,
    productDescription: card.description,
    images: preferHiResImages(product?.images ?? []),
    hasDealData: product?.hasDealData ?? false,
    sources,
    pickTypeId: card.pickTypeId,
    ribbon: card.hideRibbon ? null : card.ribbon,
  };
}

function normalizeSource(source: MinotaurSource): CommerceSource {
  return {
    merchantName: source.merchant?.name ?? "Unknown",
    affiliateUrl: source.merchant?.affiliateLink ?? null,
    priceFormatted: source.price?.formatted ?? null,
    priceRaw: source.price?.raw ?? null,
    dealAffiliateUrl: source.dealData?.affiliateLink ?? null,
    promoCode: source.dealData?.promoCode ?? null,
    promoEffect: source.dealData?.promoEffect ?? null,
    dealPriceFormatted: source.dealData?.price?.formatted ?? null,
    streetPriceFormatted: source.dealData?.streetPrice?.formatted ?? null,
  };
}

/**
 * Fallback: fetch recent review post IDs from WordPress REST API.
 */
async function fetchRecentReviewPostIds(): Promise<number[]> {
  const url =
    "https://www.nytimes.com/wirecutter/wp-json/wp/v2/review?per_page=20&orderby=modified&order=desc";
  const response = await fetch(url);
  if (!response.ok) return [];
  const posts: Array<{ id: number }> = await response.json();
  return posts.map((p) => p.id);
}

export default router;
