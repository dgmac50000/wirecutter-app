/**
 * Phoenix Crawler API client
 * Connects to the local Phoenix service for product data extraction.
 * Phoenix crawls retailer URLs and returns structured product data.
 */

const PHOENIX_URL =
  process.env.EXPO_PUBLIC_PHOENIX_URL ?? 'http://localhost:11235';

export interface PhoenixProduct {
  title: string;
  price: number | null;
  currency: string | null;
  rating: number | null;
  num_reviews: number | null;
  description: string | null;
  image_url: string | null;
  features: string[] | null;
  specs: string[] | null;
  full_specs: string[] | null;
  brand: string | null;
  availability: string | null;
  regularPrice: string;
  sku: string;
  stockStatus: string;
  discountedPrice: string;
  discount: string;
  images: string[];
  mpn: string;
  pageUrl: string;
  offerPriceDetails: string;
}

export interface CrawlResult {
  success: boolean;
  results: Array<{
    url: string;
    markdown?: { raw_markdown: string; fit_markdown: string };
    extracted_content?: string;
  }>;
  server_processing_time_s?: number;
}

/**
 * Crawl a retailer URL and get raw markdown content.
 * Use for scraping product pages without LLM extraction.
 */
export async function crawlToMarkdown(
  url: string,
  filter: 'fit' | 'raw' | 'bm25' = 'fit',
  query?: string
): Promise<string> {
  const params = new URLSearchParams({ url, f: filter });
  if (query) params.set('q', query);

  const response = await fetch(`${PHOENIX_URL}/md?${params}`);
  if (!response.ok) {
    throw new Error(
      `Phoenix /md error: ${response.status} ${response.statusText}`
    );
  }
  return response.text();
}

/**
 * Crawl one or more URLs and return full crawl results.
 */
export async function crawlUrls(urls: string[]): Promise<CrawlResult> {
  const response = await fetch(`${PHOENIX_URL}/crawl`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ urls }),
  });
  if (!response.ok) {
    throw new Error(
      `Phoenix /crawl error: ${response.status} ${response.statusText}`
    );
  }
  return response.json();
}

/**
 * Extract structured product data from a retailer URL using LLM.
 * Requires an LLM API key configured in Phoenix.
 * Returns a task ID for polling.
 */
export async function extractProduct(
  url: string,
  instruction: string = 'Extract all product information'
): Promise<{ task_id: string; status: string }> {
  const encodedUrl = encodeURIComponent(url);
  const response = await fetch(
    `${PHOENIX_URL}/llm/${encodedUrl}?q=${encodeURIComponent(instruction)}`
  );
  if (!response.ok) {
    throw new Error(
      `Phoenix /llm error: ${response.status} ${response.statusText}`
    );
  }
  return response.json();
}

/**
 * Poll a Phoenix task for completion.
 */
export async function getTaskResult(
  taskId: string
): Promise<{ status: string; result?: PhoenixProduct; error?: string }> {
  const response = await fetch(`${PHOENIX_URL}/llm/${taskId}`);
  if (!response.ok) {
    throw new Error(
      `Phoenix task error: ${response.status} ${response.statusText}`
    );
  }
  return response.json();
}

/**
 * Check Phoenix service health.
 */
export async function checkHealth(): Promise<boolean> {
  try {
    const response = await fetch(`${PHOENIX_URL}/health`);
    return response.ok;
  } catch {
    return false;
  }
}
