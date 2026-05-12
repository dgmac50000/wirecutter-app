import { Product, Category, Review, ApiResponse } from './types';

const BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? 'https://api.example.com';

async function fetchJson<T>(path: string): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`);
  if (!response.ok) {
    throw new Error(`API error: ${response.status} ${response.statusText}`);
  }
  return response.json();
}

export async function getTopPicks(): Promise<ApiResponse<Product[]>> {
  return fetchJson('/products/top-picks');
}

export async function getProduct(id: string): Promise<ApiResponse<Product>> {
  return fetchJson(`/products/${id}`);
}

export async function getCategories(): Promise<ApiResponse<Category[]>> {
  return fetchJson('/categories');
}

export async function getCategoryProducts(
  slug: string
): Promise<ApiResponse<Product[]>> {
  return fetchJson(`/categories/${slug}/products`);
}

export async function getReview(
  productId: string
): Promise<ApiResponse<Review>> {
  return fetchJson(`/products/${productId}/review`);
}

export async function searchProducts(
  query: string
): Promise<ApiResponse<Product[]>> {
  return fetchJson(`/search?q=${encodeURIComponent(query)}`);
}
