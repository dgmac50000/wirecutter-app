/**
 * Minotaur GraphQL response types
 * Mirrors the fragments in minotaur/src/graphql/persisted/posts.graphql
 */

export interface MinotaurPrice {
  raw: number;
  formatted: string;
}

export interface MinotaurMerchant {
  name: string;
  affiliateLink: string | null;
}

export interface MinotaurDealData {
  affiliateLink: string | null;
  promoCode: string | null;
  promoEffect: string | null;
  price: MinotaurPrice | null;
  streetPrice: MinotaurPrice | null;
}

export interface MinotaurSource {
  id: number;
  price: MinotaurPrice | null;
  merchant: MinotaurMerchant | null;
  dealData: MinotaurDealData | null;
}

export interface MinotaurProduct {
  id: number;
  name: string;
  images: string[];
  hasDealData: boolean;
  sources: MinotaurSource[];
}

export interface MinotaurArticleMeta {
  postId: number;
  postType: string;
  title: string;
  link: string;
  modifiedDate: string | null;
}

export interface MinotaurProductCard {
  postId: number;
  postType: string;
  productId: number;
  referenceId: number | null;
  title: string;
  description: string | null;
  pickTypeId: number | null;
  ribbon: string | null;
  hideRibbon: boolean;
  article: MinotaurArticleMeta | null;
  product: MinotaurProduct | null;
}

export interface GetProductCardsResponse {
  getProductCards: MinotaurProductCard[];
}

export interface GetScoopProductCardsResponse {
  getScoopProductCards: MinotaurProductCard[];
}
