// Generic product-page reader for any store: schema.org JSON-LD first, then product meta tags.
// Store-specific fallbacks live in read.ts; this file knows nothing about particular stores.

export type StructuredRead = {
  title: string | null;
  brand: string | null;
  price: number | null;
  originalPrice: number | null;
  inStock: boolean | null;
  pattern: string | null;
};

type Candidate = { price: number; was: number | null; inStock: boolean | null; keys: string };
type Json = Record<string, unknown>;

const num = (x: unknown) => {
  const n = typeof x === "number" ? x : typeof x === "string" ? Number(x.replace(/[,$\s]/g, "")) : NaN;
  return Number.isFinite(n) && n > 0 ? Math.round(n * 100) / 100 : null;
};
const list = (x: unknown): unknown[] => (Array.isArray(x) ? x : x === undefined || x === null ? [] : [x]);
const types = (node: Json) => list(node["@type"]).map((t) => String(t).replace(/^https?:\/\/schema\.org\//, ""));
const text = (x: unknown) => (typeof x === "string" ? x : typeof x === "object" && x ? (x as Json).name : undefined);

export function decodeEntities(s: string) {
  return s
    .replace(/&#(\d+);/g, (_, d) => String.fromCharCode(+d))
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCharCode(parseInt(h, 16)))
    .replace(/&quot;/g, '"').replace(/&apos;|&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
    .replace(/[®™©]/g, "").replace(/\s+/g, " ").trim();
}

export function jsonLdBlocks(html: string): unknown[] {
  const out: unknown[] = [];
  for (const m of html.matchAll(/<script[^>]*type=["']?application\/ld\+json["']?[^>]*>([\s\S]*?)<\/script>/gi)) {
    try {
      out.push(JSON.parse(m[1].trim().replace(/^<!--|-->$/g, "")));
    } catch {
      // Malformed blocks are common; skip them rather than guess.
    }
  }
  return out;
}

// Every Product or ProductGroup node, wherever it sits (arrays, @graph, mainEntity, itemListElement).
function productNodes(root: unknown): Json[] {
  const found: Json[] = [];
  const walk = (x: unknown, depth: number) => {
    if (depth > 6 || !x || typeof x !== "object") return;
    if (Array.isArray(x)) return x.forEach((y) => walk(y, depth + 1));
    const node = x as Json;
    const t = types(node);
    if (t.includes("Product") || t.includes("ProductGroup")) return void found.push(node);
    for (const k of ["@graph", "mainEntity", "itemListElement", "item"]) walk(node[k], depth + 1);
  };
  walk(root, 0);
  return found;
}

function offerCandidates(product: Json, inheritedKeys: string): Candidate[] {
  const keys = [inheritedKeys, product["@id"], product.url, product.sku, product.mpn, product.productID, product.color].filter(Boolean).join(" ");
  const out: Candidate[] = [];
  for (const o of list(product.offers)) {
    if (!o || typeof o !== "object") continue;
    const offer = o as Json;
    const specs = list(offer.priceSpecification).filter((s): s is Json => !!s && typeof s === "object");
    const currency = offer.priceCurrency ?? specs.find((s) => s.priceCurrency)?.priceCurrency;
    if (currency && currency !== "USD") continue;
    const listSpec = specs.find((s) => /ListPrice|StrikethroughPrice|MSRP/i.test(String(s.priceType ?? "")));
    const saleSpec = specs.find((s) => !/ListPrice|StrikethroughPrice|MSRP/i.test(String(s.priceType ?? "")) && num(s.price) !== null);
    const price = num(offer.price) ?? num(offer.lowPrice) ?? num(saleSpec?.price);
    if (price === null) continue;
    const was = num(listSpec?.price);
    const availability = String(offer.availability ?? "");
    out.push({
      price,
      was: was !== null && was > price ? was : null,
      inStock: /InStock|LimitedAvailability|OnlineOnly|PreOrder/i.test(availability) ? true : /OutOfStock|SoldOut|Discontinued/i.test(availability) ? false : null,
      keys: [keys, offer.url, "sku:" + offer.sku, "size:" + product.size, "color:" + product.color].filter(Boolean).join(" "),
    });
  }
  return out;
}

// Codes in a product URL that can single out one variant (style codes, SKUs, item numbers).
export function urlCodes(url: string | undefined): string[] {
  if (!url) return [];
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return [];
  }
  const parts = [...u.pathname.split(/[/.]/), ...[...u.searchParams.values()]];
  return [...new Set(parts.filter((p) => p.length >= 4 && /\d/.test(p) && /^[\w-]+$/.test(p)).map((p) => p.toLowerCase()))];
}

// Narrow to the variant the URL names; conflicting variant prices cannot be reduced to one observed price.
function pickCandidate(all: Candidate[], url: string | undefined): { c: Candidate; narrowed: boolean } | null {
  if (!all.length) return null;
  let pool = all;
  let narrowed = false;
  for (const code of urlCodes(url)) {
    const hits = all.filter((c) => c.keys.toLowerCase().includes(code));
    if (hits.length && hits.length < all.length) {
      pool = hits;
      narrowed = true;
      break;
    }
  }
  if (url) {
    const params = new URL(url).searchParams;
    for (const [key, value] of params) {
      if (!/^(color|sz|size|skuId|variant)$/i.test(key)) continue;
      const escaped = value.replace(/[.*+?^$()|[\]\\]/g, "\\$&");
      const field = /^(sz|size)$/i.test(key) ? "size" : /^skuId$/i.test(key) ? "sku" : key;
      const queryMatch = new RegExp("[?&]" + key + "=" + escaped + "(?=[&#\\s]|$)", "i");
      const fieldMatch = new RegExp("\\b" + field + ":" + escaped + "(?=\\s|$)", "i");
      pool = pool.filter((c) => queryMatch.test(c.keys) || fieldMatch.test(c.keys));
      if (!pool.length) return null;
      narrowed = true;
    }
  }
  const inStock = pool.filter((c) => c.inStock !== false);
  const usable = inStock.length ? inStock : pool;
  if (new Set(usable.map((c) => c.price)).size > 1) return null;
  const price = usable[0].price;
  const atPrice = usable.filter((c) => c.price === price);
  const was = atPrice.map((c) => c.was).filter((w): w is number => w !== null);
  return { c: { price, was: was.length ? Math.max(...was) : null, inStock: atPrice.some((c) => c.inStock === true) ? true : atPrice[0].inStock, keys: "" }, narrowed };
}

function metaContent(html: string, names: string[]): string | null {
  for (const name of names) {
    const esc = name.replace(/[.*+?^$()|[\]\\]/g, "\\$&");
    const m =
      html.match(new RegExp("<meta[^>]+(?:property|name|itemprop)=[\"']" + esc + "[\"'][^>]*content=[\"']([^\"']+)[\"']", "i")) ??
      html.match(new RegExp("<meta[^>]+content=[\"']([^\"']+)[\"'][^>]*(?:property|name|itemprop)=[\"']" + esc + "[\"']", "i"));
    if (m) return decodeEntities(m[1]);
  }
  return null;
}

export function readStructured(html: string, url?: string): StructuredRead {
  const products = jsonLdBlocks(html).flatMap(productNodes);
  const candidates: Candidate[] = [];
  let title: string | null = null;
  let brand: string | null = null;
  for (const p of products) {
    title ??= typeof p.name === "string" ? decodeEntities(p.name) : null;
    brand ??= text(p.brand) ? decodeEntities(String(text(p.brand))) : null;
    const groupKeys = [p["@id"], p.url, p.productGroupID].filter(Boolean).join(" ");
    candidates.push(...offerCandidates(p, ""));
    for (const variant of list(p.hasVariant)) if (variant && typeof variant === "object") candidates.push(...offerCandidates(variant as Json, groupKeys));
  }
  title ??= metaContent(html, ["og:title", "twitter:title"]) ?? (html.match(/<title[^>]*>([^<]+)<\/title>/i)?.[1] ? decodeEntities(html.match(/<title[^>]*>([^<]+)<\/title>/i)![1]) : null);
  brand ??= metaContent(html, ["product:brand", "og:brand"]);
  const picked = pickCandidate(candidates, url);
  if (picked) {
    return { title, brand, price: picked.c.price, originalPrice: picked.c.was, inStock: picked.c.inStock ?? true, pattern: picked.narrowed ? "ldjson.variant" : "ldjson" };
  }
  if (candidates.length || (url && /[?&](?:color|sz|size|skuId|variant)=/i.test(url))) {
    return { title, brand, price: null, originalPrice: null, inStock: null, pattern: null };
  }
  const currency = metaContent(html, ["product:price:currency", "og:price:currency"]);
  const metaPrice = currency && currency !== "USD" ? null : num(metaContent(html, ["product:sale_price:amount", "product:price:amount", "og:price:amount", "price"]));
  if (metaPrice !== null) {
    const was = num(metaContent(html, ["product:original_price:amount", "og:price:standard_amount", "product:retail_price:amount"]));
    return { title, brand, price: metaPrice, originalPrice: was !== null && was > metaPrice ? was : null, inStock: true, pattern: "meta" };
  }
  return { title, brand, price: null, originalPrice: null, inStock: null, pattern: null };
}
