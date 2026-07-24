#!/usr/bin/env python3
"""
Backfill product image URLs by scraping retailer product pages.

For products with Amazon affiliate URLs, extracts the ASIN and scrapes
the Amazon product page for the hiRes image URL. For other retailers,
attempts to extract og:image from the product page.
"""

import json
import re
import time
import urllib.request
import urllib.error
import ssl
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Optional, Tuple, List, Dict

REPO_ROOT = Path(__file__).resolve().parent.parent
PRODUCTS_PATH = REPO_ROOT / "WirecutterApp" / "WirecutterApp" / "products.json"

BATCH_SIZE = 10
DELAY_BETWEEN_BATCHES = 2.0
REQUEST_TIMEOUT = 15

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
)

ASIN_RE = re.compile(r"amazon\.com/(?:dp|gp/product)/([A-Z0-9]{10})")
AMAZON_HIRES_RE = re.compile(r'"hiRes":"(https://m\.media-amazon\.com/images/I/[^"]+)"')
AMAZON_LANDING_RE = re.compile(
    r'"landing":\s*\["(https://m\.media-amazon\.com/images/I/[^"]+)"'
)
OG_IMAGE_RE = re.compile(
    r'<meta[^>]*property=["\']og:image["\'][^>]*content=["\']([^"\']+)["\']'
    r"|<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*property=[\"']og:image[\"']",
    re.IGNORECASE,
)

SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE


def fetch_url(url: str) -> str:
    req = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "en-US,en;q=0.9",
    })
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT, context=SSL_CTX) as resp:
        return resp.read().decode("utf-8", errors="replace")


def get_amazon_image(asin: str) -> Optional[str]:
    try:
        html = fetch_url(f"https://www.amazon.com/dp/{asin}/")
        m = AMAZON_HIRES_RE.search(html)
        if m:
            return m.group(1)
        m = AMAZON_LANDING_RE.search(html)
        if m:
            return m.group(1)
    except Exception:
        pass
    return None


def get_og_image(url: str) -> Optional[str]:
    try:
        html = fetch_url(url)
        m = OG_IMAGE_RE.search(html)
        if m:
            return m.group(1) or m.group(2)
    except Exception:
        pass
    return None


def extract_asin(sources: List[dict]) -> Optional[str]:
    for s in sources:
        url = s.get("affiliateUrl") or ""
        m = ASIN_RE.search(url)
        if m:
            return m.group(1)
    return None


def get_best_non_amazon_url(sources: List[dict]) -> Optional[str]:
    """Find a scrapable retailer URL from product sources."""
    skip_domains = {"amazon.com", "wclink.co"}
    for s in sources:
        url = s.get("affiliateUrl") or ""
        if not url or any(d in url for d in skip_domains):
            continue
        if url.startswith("http"):
            return url
    return None


def fetch_image_for_product(product: dict) -> Tuple[int, Optional[str]]:
    """Returns (productId, imageUrl or None)."""
    pid = product["productId"]
    sources = product.get("sources") or []

    asin = extract_asin(sources)
    if asin:
        img = get_amazon_image(asin)
        if img:
            return pid, img

    retailer_url = get_best_non_amazon_url(sources)
    if retailer_url:
        img = get_og_image(retailer_url)
        if img:
            return pid, img

    return pid, None


def main():
    print("Loading current products.json...")
    with open(PRODUCTS_PATH) as f:
        current_data = json.load(f)
    products = current_data["products"]

    needs_images = [p for p in products if not p.get("imageUrl")]
    already_has = len(products) - len(needs_images)
    print(f"Total products: {len(products)}")
    print(f"Already have images: {already_has}")
    print(f"Need images: {len(needs_images)}")

    amazon_products = []
    other_products = []
    for p in needs_images:
        sources = p.get("sources") or []
        if extract_asin(sources):
            amazon_products.append(p)
        elif get_best_non_amazon_url(sources):
            other_products.append(p)

    print(f"\n  With Amazon ASIN: {len(amazon_products)}")
    print(f"  With other retailer URL: {len(other_products)}")
    print(f"  No scrapable URL: {len(needs_images) - len(amazon_products) - len(other_products)}")

    product_by_id = {p["productId"]: p for p in products}
    all_to_scrape = amazon_products + other_products
    matched = 0
    failed = 0
    total = len(all_to_scrape)

    print(f"\nScraping {total} product pages...")

    for batch_start in range(0, total, BATCH_SIZE):
        batch = all_to_scrape[batch_start : batch_start + BATCH_SIZE]

        with ThreadPoolExecutor(max_workers=BATCH_SIZE) as executor:
            futures = {
                executor.submit(fetch_image_for_product, p): p for p in batch
            }
            for future in as_completed(futures):
                pid, img_url = future.result()
                if img_url:
                    product_by_id[pid]["images"] = [img_url]
                    product_by_id[pid]["imageUrl"] = img_url
                    matched += 1
                else:
                    failed += 1

        done = min(batch_start + BATCH_SIZE, total)
        print(f"  [{done}/{total}] matched={matched} failed={failed}")

        if done < total:
            time.sleep(DELAY_BETWEEN_BATCHES)

    total_with_images = sum(1 for p in products if p.get("imageUrl"))
    print(f"\nResults:")
    print(f"  Newly matched: {matched}")
    print(f"  Failed to scrape: {failed}")
    print(f"  Final products with images: {total_with_images} / {len(products)}")

    if matched > 0:
        with open(PRODUCTS_PATH, "w") as f:
            json.dump(current_data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"  Saved updated products.json")

    still_missing = [p for p in products if not p.get("imageUrl")]
    if still_missing:
        print(f"\nStill missing images ({len(still_missing)}):")
        for p in still_missing[:15]:
            print(f"  [{p['productId']}] {p['productTitle']}")


if __name__ == "__main__":
    main()
