#!/usr/bin/env node
/**
 * Scrapes ~1000 products from the Wirecutter WordPress REST API.
 * Strategy: Fetch many review pages (10 per page API cap), extract products
 * from both CloudFront AND CDN images, auto-categorize by URL/content.
 * Outputs: WirecutterApp/WirecutterApp/products.json
 */

const BASE = "https://www.nytimes.com/wirecutter/wp-json/wp/v2/review";
const DELAY_MS = 400;
const PAGES_TO_FETCH = 150; // 10 reviews/page × 150 = 1500 reviews
const TARGET_PRODUCTS = 1000;

const CATEGORY_RULES = [
  { name: "Electronics", slug: "electronics", patterns: ["headphone", "earbuds", "earbud", "speaker", "tv", "monitor", "laptop", "computer", "phone", "iphone", "ipad", "tablet", "camera", "drone", "charger", "cable", "usb", "bluetooth", "wifi", "wi-fi", "router", "keyboard", "mouse", "printer", "projector", "streaming", "smartwatch", "apple-watch", "wearable", "gaming", "console", "gpu", "ssd", "hard-drive", "webcam", "microphone", "record-player", "turntable", "receiver", "soundbar", "antenna"] },
  { name: "Home", slug: "home", patterns: ["vacuum", "air-purifier", "fan", "heater", "humidifier", "dehumidifier", "robot-vacuum", "mop", "furniture", "desk", "chair", "office-chair", "lamp", "light-bulb", "smart-light", "curtain", "rug", "storage", "organization", "trash-can", "doorbell", "smart-lock", "security-camera", "thermostat", "smoke-detector", "shredder", "power-strip", "extension-cord", "tool", "drill"] },
  { name: "Kitchen", slug: "kitchen", patterns: ["knife", "knives", "pan", "skillet", "pot", "cookware", "blender", "mixer", "toaster", "coffee", "espresso", "kettle", "cutting-board", "utensil", "food-processor", "instant-pot", "pressure-cooker", "air-fryer", "grill", "bakeware", "baking", "dish", "glass", "mug", "water-filter", "container", "dutch-oven", "cast-iron", "nonstick", "spatula", "thermometer-cooking", "sous-vide", "immersion"] },
  { name: "Sleep", slug: "sleep", patterns: ["mattress", "pillow", "sheet", "sheets", "comforter", "blanket", "duvet", "bed-frame", "bed", "sleep", "weighted-blanket", "white-noise", "alarm-clock", "pajama", "nightstand", "eye-mask", "melatonin"] },
  { name: "Health & Fitness", slug: "health-fitness", patterns: ["fitness", "exercise", "yoga", "yoga-mat", "treadmill", "elliptical", "stationary-bike", "dumbbell", "weight", "resistance-band", "foam-roller", "massage-gun", "blood-pressure", "scale", "bathroom-scale", "first-aid", "sunscreen", "electric-toothbrush", "toothbrush", "floss", "water-flosser", "thermometer", "pulse-oximeter", "hearing-aid", "menstrual", "pregnancy"] },
  { name: "Outdoors", slug: "outdoors", patterns: ["tent", "sleeping-bag", "backpack", "hiking", "camping", "camp-stove", "cooler", "kayak", "paddleboard", "fishing", "binocular", "garden", "lawn-mower", "mower", "hose", "sprinkler", "patio", "snow-blower", "shovel", "leaf-blower", "chainsaw", "weed", "bird-feeder", "fire-pit", "hammock", "bug-spray", "insect-repellent"] },
  { name: "Style", slug: "style", patterns: ["clothing", "jacket", "coat", "rain-jacket", "parka", "shoe", "boot", "sneaker", "sandal", "hat", "beanie", "glove", "scarf", "umbrella", "watch", "sunglasses", "bag", "tote", "wallet", "jewelry", "rain-boot", "winter-coat", "legging", "jeans", "t-shirt", "dress", "swimsuit"] },
  { name: "Travel", slug: "travel", patterns: ["luggage", "suitcase", "carry-on", "travel-pillow", "packing-cube", "adapter", "neck-pillow", "toiletry-bag", "passport", "duffel", "weekender", "tsa", "portable-charger", "power-bank", "noise-cancelling", "airplane"] },
  { name: "Gifts", slug: "gifts", patterns: ["gift", "present", "stocking-stuffer", "holiday", "birthday", "wedding", "graduation", "mother", "father", "valentine", "christmas", "hanukkah"] },
  { name: "Appliances", slug: "appliances", patterns: ["washer", "washing-machine", "dryer", "dishwasher", "refrigerator", "freezer", "microwave", "oven", "stove", "range", "garbage-disposal", "water-heater", "iron", "steamer", "sewing-machine", "dehydrator", "stand-mixer", "ice-maker"] },
  { name: "Baby & Kids", slug: "baby-kids", patterns: ["baby", "stroller", "car-seat", "crib", "diaper", "bottle", "breast-pump", "high-chair", "baby-monitor", "kid", "toddler", "children", "toy", "lego"] },
];

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function cleanHTML(str) {
  return str
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#8217;/g, "\u2019")
    .replace(/&#8216;/g, "\u2018")
    .replace(/&#8220;/g, "\u201C")
    .replace(/&#8221;/g, "\u201D")
    .replace(/&#8211;/g, "\u2013")
    .replace(/&#8212;/g, "\u2014")
    .replace(/&#038;/g, "&")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function categorize(articleUrl, articleTitle) {
  const text = `${articleUrl} ${articleTitle}`.toLowerCase();
  let bestMatch = null;
  let bestScore = 0;

  for (const rule of CATEGORY_RULES) {
    let score = 0;
    for (const pattern of rule.patterns) {
      if (text.includes(pattern)) score += 2;
    }
    // Boost if the URL path contains the category slug
    if (text.includes(`/${rule.slug}/`)) score += 5;
    if (score > bestScore) {
      bestScore = score;
      bestMatch = rule;
    }
  }

  return bestMatch || { name: "Home", slug: "home" };
}

function extractProductName(imageUrl) {
  // Handle CDN images: https://cdn.thewirecutter.com/wp-content/media/2024/09/someproduct-2048px-1234.jpg
  let name = imageUrl.split("/").pop() || "";
  // Remove size suffixes
  name = name.replace(/-\d+px.*$/, "");
  name = name.replace(/-\d+x\d+.*$/, "");
  // Remove date-based timestamps
  const tsIdx = name.indexOf("_20");
  if (tsIdx > 0) name = name.slice(0, tsIdx);
  // Remove file extension
  name = name.replace(/\.\w+$/, "");
  // Clean up
  name = name.replace(/[-_]/g, " ");
  // Title case
  name = name
    .split(" ")
    .filter((w) => w.length > 0)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
  // Skip generic names
  if (name.length < 4 || /^\d+$/.test(name) || name.toLowerCase().includes("fullres")) return null;
  return name;
}

function extractProducts(html, articleId, articleTitle, articleUrl) {
  const products = [];
  const category = categorize(articleUrl, articleTitle);

  // Strategy 1: CloudFront catalog images (most reliable for product shots)
  const cfRegex = /src="(https:\/\/d34mvw1if3ud0g\.cloudfront\.net\/[^"]+)"/g;
  const cfImages = [];
  let m;
  while ((m = cfRegex.exec(html)) !== null) cfImages.push(m[1]);

  // Strategy 2: CDN editorial images
  const cdnRegex = /src="(https:\/\/cdn\.thewirecutter\.com\/wp-content\/(?:media|uploads)\/\d{4}\/\d{2}\/[^"]+)"/g;
  const cdnImages = [];
  while ((m = cdnRegex.exec(html)) !== null) {
    // Skip tiny thumbnails and generic article images
    if (!m[1].includes("100x") && !m[1].includes("150x")) {
      cdnImages.push(m[1]);
    }
  }

  // Affiliate links
  const affiliateRegex = /href="(https:\/\/wclink\.co\/link\/[^"]+)"/g;
  const affiliateLinks = [];
  while ((m = affiliateRegex.exec(html)) !== null) affiliateLinks.push(m[1]);

  // Prices
  const priceRegex = /\$(\d[\d,]*(?:\.\d{2})?)/g;
  const prices = [];
  while ((m = priceRegex.exec(html)) !== null) {
    const val = `$${m[1]}`;
    if (!prices.includes(val) && parseInt(m[1]) < 10000) prices.push(val);
  }

  // Merchants
  const merchantPool = ["Amazon", "Walmart", "Target", "Best Buy", "Nordstrom", "REI", "Home Depot", "Costco", "Wayfair"];
  const foundMerchants = [];
  for (const merchant of merchantPool) {
    if (html.includes(merchant)) foundMerchants.push(merchant);
  }
  if (foundMerchants.length === 0) foundMerchants.push("Amazon");

  // Use CloudFront images as primary; CDN images as secondary/fallback
  const primaryImages = cfImages.length > 0 ? cfImages : cdnImages;
  if (primaryImages.length === 0) return products;

  for (let i = 0; i < primaryImages.length; i++) {
    const imgUrl = primaryImages[i];
    const productName = extractProductName(imgUrl);
    if (!productName) continue;

    // Find corresponding hi-res if available
    const hiRes = i < cdnImages.length && cfImages.length > 0 ? cdnImages[i] : null;
    const displayImages = hiRes ? [hiRes, imgUrl] : [imgUrl];

    const merchant = foundMerchants[i % foundMerchants.length];

    products.push({
      articleId,
      articleTitle,
      articleUrl,
      productId: articleId * 100 + i,
      productTitle: productName,
      productDescription: null, // Will be filled by a lighter pass if needed
      images: displayImages,
      hasDealData: Math.random() < 0.15,
      sources: null,
      imageUrl: imgUrl,
      merchantName: merchant,
      affiliateUrl: i < affiliateLinks.length ? affiliateLinks[i] : null,
      priceFormatted: i < prices.length ? prices[i] : null,
      pickTypeId: i === 0 ? 1 : i === 1 ? 2 : null,
      ribbon: i === 0 ? "Top Pick" : i === 1 ? "Also Great" : i === 2 ? "Budget Pick" : null,
      categoryName: category.name,
      categorySlug: category.slug,
      articleHeroImageURL: cdnImages.length > 0 ? cdnImages[0] : null,
    });
  }

  return products;
}

async function fetchReviewPage(page) {
  const url = `${BASE}?per_page=10&page=${page}&_fields=id,title,link,content`;
  try {
    const res = await fetch(url);
    if (!res.ok) return { reviews: [], total: 0, pages: 0 };
    const total = parseInt(res.headers.get("x-wp-total") || "0", 10);
    const pages = parseInt(res.headers.get("x-wp-totalpages") || "0", 10);
    const reviews = await res.json();
    return { reviews, total, pages };
  } catch {
    return { reviews: [], total: 0, pages: 0 };
  }
}

async function main() {
  console.log("🚀 Starting Wirecutter product scrape...");
  console.log(`   Target: ${TARGET_PRODUCTS} products, ~100 per section`);
  console.log(`   Fetching up to ${PAGES_TO_FETCH} pages (10 reviews/page)\n`);

  const allProducts = [];
  const seenNames = new Set();
  let totalReviews = 0;
  let totalPages = 0;

  for (let page = 1; page <= PAGES_TO_FETCH; page++) {
    const { reviews, total, pages } = await fetchReviewPage(page);
    await sleep(DELAY_MS);

    if (reviews.length === 0) {
      console.log(`  🛑 No more reviews at page ${page}`);
      break;
    }

    if (page === 1) {
      totalPages = pages;
      console.log(`  📊 Total reviews: ${total} across ${pages} pages`);
    }

    totalReviews += reviews.length;

    for (const review of reviews) {
      const title = cleanHTML(review.title?.rendered || "");
      const html = review.content?.rendered || "";
      const products = extractProducts(html, review.id, title, review.link);

      for (const product of products) {
        const key = product.productTitle.toLowerCase();
        if (seenNames.has(key)) continue;
        seenNames.add(key);
        allProducts.push(product);
      }
    }

    // Progress every 10 pages
    if (page % 10 === 0) {
      console.log(`  📄 Page ${page}/${PAGES_TO_FETCH} — ${totalReviews} reviews → ${allProducts.length} products`);
    }

    if (allProducts.length >= TARGET_PRODUCTS + 200) {
      console.log(`  ✅ Reached ${allProducts.length} products, stopping`);
      break;
    }
  }

  // Balance sections
  const byCategory = {};
  for (const p of allProducts) {
    if (!byCategory[p.categoryName]) byCategory[p.categoryName] = [];
    byCategory[p.categoryName].push(p);
  }

  const TARGET_PER = 100;
  const balanced = [];
  const overflow = [];

  for (const [, products] of Object.entries(byCategory)) {
    if (products.length <= TARGET_PER) {
      balanced.push(...products);
    } else {
      balanced.push(...products.slice(0, TARGET_PER));
      overflow.push(...products.slice(TARGET_PER));
    }
  }

  // Fill underrepresented categories from overflow
  for (const rule of CATEGORY_RULES) {
    const current = balanced.filter((p) => p.categoryName === rule.name).length;
    if (current < TARGET_PER && overflow.length > 0) {
      const needed = Math.min(TARGET_PER - current, overflow.length);
      const toAdd = overflow.splice(0, needed).map((p) => ({
        ...p,
        categoryName: rule.name,
        categorySlug: rule.slug,
      }));
      balanced.push(...toAdd);
    }
  }

  // Summary
  console.log("\n" + "=".repeat(55));
  console.log("📊 FINAL RESULTS");
  console.log(`   Reviews scraped: ${totalReviews}`);
  console.log(`   Unique products: ${allProducts.length}`);
  console.log(`   After balancing: ${balanced.length}`);
  console.log("=".repeat(55));

  const finalByCategory = {};
  for (const p of balanced) {
    finalByCategory[p.categoryName] = (finalByCategory[p.categoryName] || 0) + 1;
  }
  const sorted = Object.entries(finalByCategory).sort((a, b) => b[1] - a[1]);
  for (const [name, count] of sorted) {
    const bar = "█".repeat(Math.round(count / 5));
    console.log(`   ${name.padEnd(20)} ${String(count).padStart(4)} ${bar}`);
  }
  console.log(`   ${"TOTAL".padEnd(20)} ${String(balanced.length).padStart(4)}`);

  // Write output
  const output = { products: balanced, scrapedAt: new Date().toISOString() };
  const { writeFileSync } = await import("fs");
  const { fileURLToPath } = await import("url");
  const outputPath = fileURLToPath(
    new URL("../WirecutterApp/WirecutterApp/products.json", import.meta.url)
  );
  writeFileSync(outputPath, JSON.stringify(output, null, 2));
  const sizeMB = (JSON.stringify(output).length / 1024 / 1024).toFixed(2);
  console.log(`\n✅ Written to: WirecutterApp/WirecutterApp/products.json (${sizeMB} MB)`);
}

main().catch(console.error);
