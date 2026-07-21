/**
 * Prefer editorial hi-res Wirecutter CDN assets over smaller catalog / Phoenix shots.
 * Mirrors the tier logic in the product-images PDP tool and Swift ProductImageRanking.
 */

export type ImageTier = "hires" | "catalog" | "unknown";

export function imageTier(url: string): ImageTier {
  const lower = url.toLowerCase();
  if (
    lower.includes("cdn.thewirecutter.com") ||
    lower.includes("/wp-content/media/") ||
    lower.includes("2048px")
  ) {
    return "hires";
  }
  if (
    lower.includes("d34mvw1if3ud0g.cloudfront.net") ||
    lower.includes("phoenixstagingimages") ||
    lower.includes("product_images")
  ) {
    return "catalog";
  }
  return "unknown";
}

const TIER_RANK: Record<ImageTier, number> = {
  hires: 2,
  unknown: 1,
  catalog: 0,
};

/** Normalize WP upload paths to the public media CDN path. */
export function normalizeMediaUrl(url: string): string {
  return url.replace("/wp-content/uploads/", "/wp-content/media/");
}

/** Stable sort: hi-res first, then unknown, then catalog. */
export function preferHiResImages(urls: string[]): string[] {
  return urls
    .map((url, index) => ({ url: normalizeMediaUrl(url), index }))
    .sort((a, b) => {
      const rankDiff = TIER_RANK[imageTier(b.url)] - TIER_RANK[imageTier(a.url)];
      if (rankDiff !== 0) return rankDiff;
      return a.index - b.index;
    })
    .map(({ url }) => url);
}
