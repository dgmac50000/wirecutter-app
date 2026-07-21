/**
 * CommerceItem DTO — the normalized JSON shape returned to the iOS app.
 */

export interface CommerceSource {
  merchantName: string;
  affiliateUrl: string | null;
  priceFormatted: string | null;
  priceRaw: number | null;
  dealAffiliateUrl: string | null;
  promoCode: string | null;
  promoEffect: string | null;
  dealPriceFormatted: string | null;
  streetPriceFormatted: string | null;
}

export interface CommerceItem {
  articleId: number;
  articleTitle: string;
  articleUrl: string;
  productId: number;
  productTitle: string;
  productDescription: string | null;
  images: string[];
  hasDealData: boolean;
  sources: CommerceSource[];
  pickTypeId: number | null;
  ribbon: string | null;
}

export interface CommerceFeedResponse {
  items: CommerceItem[];
}
