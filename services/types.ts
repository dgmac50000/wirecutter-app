export interface Product {
  id: string;
  title: string;
  subtitle: string;
  category: string;
  imageUrl: string;
  badge?: 'top-pick' | 'budget-pick' | 'upgrade-pick';
  rating?: number;
  priceRange?: string;
  lastUpdated: string;
}

export interface Category {
  slug: string;
  name: string;
  description: string;
  imageUrl: string;
  productCount: number;
}

export interface Review {
  id: string;
  productId: string;
  headline: string;
  summary: string;
  pros: string[];
  cons: string[];
  verdict: string;
  author: string;
  publishedAt: string;
  updatedAt: string;
}

export interface ApiResponse<T> {
  data: T;
  meta?: {
    page: number;
    totalPages: number;
    totalItems: number;
  };
}
