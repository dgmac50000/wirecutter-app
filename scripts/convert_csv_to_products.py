#!/usr/bin/env python3
"""Convert products-by-section.csv to the app's products.json format,
enriching with image URLs from the existing products.json."""

import csv
import json
import re
from datetime import datetime, timezone
from pathlib import Path

CSV_PATH = Path("/Users/dariusguerrero/Downloads/products-by-section.csv")
EXISTING_JSON = Path("/Users/dariusguerrero/Projects/wirecutter-app/WirecutterApp/WirecutterApp/products.json")
OUTPUT_PATH = EXISTING_JSON

INCLUDED_SECTIONS = {
    "Electronics", "Home", "Kitchen", "Appliances", "Sleep",
    "Health and fitness", "Outdoors", "Style", "Travel", "Gifts",
    "Baby and kid", "Beauty", "Office", "Games and hobbies", "Pets",
}

SECTION_NAME_MAP = {
    "Health and fitness": "Health & Fitness",
    "Baby and kid": "Baby & Kid",
    "Games and hobbies": "Games & Hobbies",
}

SECTION_SLUG_MAP = {
    "Health and fitness": "health-fitness",
    "Baby and kid": "baby-and-kid",
    "Games and hobbies": "games-and-hobbies",
}


def make_slug(section: str) -> str:
    if section in SECTION_SLUG_MAP:
        return SECTION_SLUG_MAP[section]
    return section.lower().replace(" ", "-").replace("&", "and")


def make_display_name(section: str) -> str:
    return SECTION_NAME_MAP.get(section, section)


def normalize_name(s: str) -> str:
    """Normalize product name for fuzzy matching."""
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def build_image_lookup(existing_path: Path) -> dict:
    """Build normalized product name -> {images, imageUrl} from existing products.json."""
    with open(existing_path, "r") as f:
        data = json.load(f)

    lookup = {}
    for product in data["products"]:
        name = normalize_name(product.get("productTitle", ""))
        if name:
            lookup[name] = {
                "images": product.get("images"),
                "imageUrl": product.get("imageUrl"),
            }
    return lookup


def parse_buy_sources(raw: str) -> list:
    """Parse the buy_sources JSON string from CSV."""
    if not raw or raw == "NULL":
        return []
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return []


def map_sources(buy_sources: list, available_only: bool) -> list:
    """Map buy_sources to CommerceSource format."""
    if available_only:
        filtered = [s for s in buy_sources if s.get("availability") == 1]
    else:
        filtered = buy_sources

    filtered.sort(key=lambda s: s.get("display_order", 0))

    return [
        {
            "merchantName": s.get("merchant"),
            "affiliateUrl": s.get("url"),
            "priceFormatted": s.get("price"),
            "priceRaw": s.get("price_cents"),
            "dealAffiliateUrl": None,
            "promoCode": None,
            "promoEffect": None,
            "dealPriceFormatted": None,
            "streetPriceFormatted": None,
        }
        for s in filtered
    ]


def convert():
    image_lookup = build_image_lookup(EXISTING_JSON)
    print(f"Loaded image lookup: {len(image_lookup)} products with images")

    products = []
    section_counts = {}
    matched_images = 0
    total_csv = 0
    skipped_sections = set()

    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=";", escapechar="\\", doublequote=False)
        for row in reader:
            total_csv += 1
            section = row.get("section", "").strip().strip('"')

            if section not in INCLUDED_SECTIONS:
                skipped_sections.add(section)
                continue

            product_id = int(row["product_id"].strip().strip('"'))
            product_name = row["product_name"].strip().strip('"')
            price = row.get("price", "").strip().strip('"')
            buy_sources_raw = row.get("buy_sources", "").strip().strip('"')
            buy_sources = parse_buy_sources(buy_sources_raw)

            has_available = any(s.get("availability") == 1 for s in buy_sources)
            sources = map_sources(buy_sources, available_only=has_available)

            first_source = sources[0] if sources else None

            img_data = image_lookup.get(normalize_name(product_name), {})
            images = img_data.get("images")
            image_url = img_data.get("imageUrl")
            if images or image_url:
                matched_images += 1

            is_shopify = any(
                s.get("merchant") == "Wirecutter Store" for s in buy_sources
            )

            article_id = product_id // 100
            display_name = make_display_name(section)
            slug = make_slug(section)

            product = {
                "articleId": article_id,
                "articleTitle": f"{display_name} Picks",
                "articleUrl": "https://www.nytimes.com/wirecutter/",
                "productId": product_id,
                "productTitle": product_name,
                "productDescription": None,
                "images": images,
                "hasDealData": has_available,
                "sources": sources if sources else None,
                "imageUrl": image_url,
                "merchantName": first_source["merchantName"] if first_source else None,
                "affiliateUrl": first_source["affiliateUrl"] if first_source else None,
                "priceFormatted": price if price and price != "$0.00" else None,
                "pickTypeId": None,
                "ribbon": None,
                "categoryName": display_name,
                "categorySlug": slug,
                "articleHeroImageURL": None,
                "isShopifyProduct": is_shopify,
                "shopifyVariantId": None,
            }

            products.append(product)
            section_counts[display_name] = section_counts.get(display_name, 0) + 1

    output = {
        "products": products,
        "scrapedAt": datetime.now(timezone.utc).isoformat(),
    }

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nTotal CSV rows: {total_csv}")
    print(f"Products included: {len(products)}")
    print(f"Products with matched images: {matched_images}")
    print(f"Skipped sections: {sorted(skipped_sections)}")
    print(f"\nProducts per section:")
    for section, count in sorted(section_counts.items(), key=lambda x: -x[1]):
        print(f"  {section}: {count}")
    print(f"\nOutput written to: {OUTPUT_PATH}")


if __name__ == "__main__":
    convert()
