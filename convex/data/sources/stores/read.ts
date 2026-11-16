import { readStructured, type StructuredRead } from "./structured";
import { parseUrl } from "./url";

// Product pages from brand stores (and any store without its own parser): the generic JSON-LD/meta reader,
// plus store-specific extras where it misses something we need. JSON-LD carries the price but rarely the "was" price.

export type StoreRead = StructuredRead & { blocked: boolean };

const BLOCKED = /captcha|access denied|access to this page has been denied|are you a human|verify you are human|request unsuccessful/i;

// Nike embeds each style-color's prices after its path: ".../FD2722-001"},"prices":{"currency":"USD","currentPrice":108.97,"initialPrice":145,...}
function nikePrices(html: string, code: string | undefined) {
  if (!code) return null;
  const esc = code.replace(/[^A-Za-z0-9-]/g, "");
  const m = html.match(new RegExp(esc + '"\\},"prices":\\{"currency":"USD",[^}]*?"currentPrice":([\\d.]+),"initialPrice":([\\d.]+)', "i"));
  return m ? { price: Number(m[1]), was: Number(m[2]) } : null;
}

// American Eagle lists every size with its sale and list price: {"sizeName":"28 X 30","salePrice":34.96,...,"listPrice":49.95}
function aeListPrice(html: string, price: number | null) {
  for (const m of html.matchAll(/"salePrice":([\d.]+),[^{}]*?"listPrice":([\d.]+)/g)) {
    if (price === null || Number(m[1]) === price) return { price: Number(m[1]), was: Number(m[2]) };
  }
  return null;
}

function withWas(read: StructuredRead, extra: { price: number; was: number } | null, pattern: string) {
  if (!extra) return;
  read.price ??= extra.price;
  if (extra.was > read.price) read.originalPrice = extra.was;
  read.inStock ??= true;
  read.pattern ??= pattern;
}

export function readStorePage(retailer: string, html: string, url?: string): StoreRead {
  const read = readStructured(html, url);
  if (read.price === null && url && /[?&](?:color|sz|size|skuId|variant)=/i.test(url)) return { ...read, blocked: false };
  if (retailer === "nike") withWas(read, nikePrices(html, url ? parseUrl(url)?.productCode : undefined), "nike.prices");
  if (retailer === "ae") withWas(read, aeListPrice(html, read.price), "ae.sku");
  // Archived bot-wall stubs are tiny; a real product page is hundreds of KB.
  const blocked = read.price === null && (html.length < 20000 || BLOCKED.test(html.slice(0, 20000)));
  return { ...read, blocked };
}
