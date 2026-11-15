// URL-only reading of store product links: which known retailer, a product code, and a title hint from the slug.
// No network, so the live path can use it. The hint is the de-slugged path and only a hint.

export type ParsedUrl = { retailer: string; productCode?: string; titleHint?: string; url: string };

type Rule = {
  retailer: string;
  host: RegExp;
  code: RegExp;
  // Index of the path segment that carries the product slug, found relative to a marker segment.
  slug: (segments: string[]) => string | undefined;
  brand?: string;
};

const after = (marker: string) => (s: string[]) => s[s.indexOf(marker) + 1] && s.indexOf(marker) >= 0 ? s[s.indexOf(marker) + 1] : undefined;
const before = (marker: string) => (s: string[]) => (s.indexOf(marker) > 0 ? s[s.indexOf(marker) - 1] : undefined);

const RULES: Rule[] = [
  { retailer: "amazon", host: /(^|\.)amazon\.com$/, code: /\/(?:dp|gp\/product|gp\/aw\/d)\/([A-Z0-9]{10})/i, slug: before("dp") },
  { retailer: "walmart", host: /(^|\.)walmart\.com$/, code: /\/ip\/(?:[^/]+\/)?(\d{5,})/, slug: after("ip") },
  { retailer: "target", host: /(^|\.)target\.com$/, code: /\/A-(\d{6,})/, slug: after("p") },
  { retailer: "bestbuy", host: /(^|\.)bestbuy\.com$/, code: /\/(?:product\/[^/]+\/([A-Z0-9]{8,12})|site\/[^/]+\/(\d{7})\.p)/i, slug: (s) => after("product")(s) ?? after("site")(s) },
  // nike.com/t/pegasus-41-mens-road-running-shoes-LMhfRGdO/FD2722-001: the slug ends in a group id, the last part is the style-color.
  { retailer: "nike", host: /(^|\.)nike\.com$/, code: /\/t\/[^/]+\/([A-Z0-9]{6}-\d{3})/i, slug: (s) => after("t")(s)?.replace(/-[A-Za-z0-9]{6,8}$/, ""), brand: "Nike" },
  // shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012
  { retailer: "lululemon", host: /(^|\.)lululemon\.com$/, code: /\/(prod\d{5,})/, slug: before("_"), brand: "lululemon" },
  // ae.com/us/en/p/men/jeans/baggy-loose-jeans/ae-baggy-jean/1114_7364_914
  { retailer: "ae", host: /(^|\.)ae\.com$/, code: /\/(\d{4}_\d{4}_\d{3})/, slug: (s) => s[s.length - 2], brand: "AE" },
  // apple.com/shop/buy-airpods/airpods-pro-3 or apple.com/shop/product/MX2D3AM/A/airpods-4
  { retailer: "apple", host: /(^|\.)apple\.com$/, code: /\/shop\/(?:product\/([A-Z0-9]{5,}\/A)|buy-[a-z]+\/([a-z0-9-]+))/i, slug: (s) => (s.includes("product") ? s[s.length - 1] : after(s.find((x) => x.startsWith("buy-")) ?? "")(s)), brand: "Apple" },
];

function deslug(segment: string | undefined): string | undefined {
  if (!segment) return undefined;
  let s = segment;
  try {
    s = decodeURIComponent(segment);
  } catch {
    // keep the raw segment
  }
  const words = s.replace(/\.html?$/, "").split(/[-_+\s]+/).filter(Boolean);
  return words.length >= 2 && /[a-z]/i.test(s) ? words.join(" ") : undefined;
}

export function parseUrl(raw: string): ParsedUrl | null {
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (!/^https?:$/.test(u.protocol) || u.username || u.password || u.port) return null;
  const host = u.hostname.toLowerCase();
  const allowedHosts = ["amazon.com", "walmart.com", "target.com", "bestbuy.com", "nike.com", "ae.com", "apple.com"];
  if (host !== "shop.lululemon.com" && !allowedHosts.some((domain) => host === domain || host === "www." + domain)) return null;
  const rule = RULES.find((r) => r.host.test(host));
  if (!rule) return null;
  const m = u.pathname.match(rule.code);
  if (!m) return null;
  const productCode = m ? (m.slice(1).find(Boolean) ?? undefined) : undefined;
  let titleHint = deslug(rule.slug(u.pathname.split("/").filter(Boolean)));
  if (titleHint && rule.brand && !titleHint.toLowerCase().includes(rule.brand.toLowerCase())) titleHint = rule.brand + " " + titleHint;
  const canonical = rule.retailer === "amazon" && productCode ? "https://www.amazon.com/dp/" + productCode : "https://" + host + u.pathname;
  return { retailer: rule.retailer, productCode, titleHint, url: canonical };
}
