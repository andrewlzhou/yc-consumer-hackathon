// Retailer names as phones and APIs write them, mapped to our slugs.

export const KNOWN_RETAILERS = [
  { slug: "target", name: "Target", domain: "target.com", aliases: ["target"] },
  { slug: "walmart", name: "Walmart", domain: "walmart.com", aliases: ["walmart", "wal-mart"] },
  { slug: "bestbuy", name: "Best Buy", domain: "bestbuy.com", aliases: ["best buy", "bestbuy"] },
  { slug: "amazon", name: "Amazon", domain: "amazon.com", aliases: ["amazon", "amzn"] },
  // Brand stores (stores thread, docs/backend/data-stores.md). Aliases include the names Google Shopping uses.
  { slug: "nike", name: "Nike", domain: "nike.com", aliases: ["nike", "nike store"] },
  { slug: "ae", name: "American Eagle", domain: "ae.com", aliases: ["ae", "american eagle", "american eagle outfitters", "aeo"] },
  { slug: "lululemon", name: "lululemon", domain: "lululemon.com", aliases: ["lululemon", "shop.lululemon", "lululemon athletica"] },
  { slug: "apple", name: "Apple", domain: "apple.com", aliases: ["apple", "apple store"] },
];

// Only retailers we know map to a slug; anything else is null so untrusted strings never create rows.
export function normalizeRetailer(raw: string | undefined): string | null {
  if (!raw) return null;
  const cleaned = raw
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/^www\./, "")
    .replace(/\.com.*$/, "")
    .replace(/[^a-z0-9 -]/g, "")
    .trim();
  if (!cleaned) return null;
  const known = KNOWN_RETAILERS.find(
    (r) => r.slug === cleaned.replace(/\s+/g, "") || r.aliases.includes(cleaned),
  );
  return known ? known.slug : null;
}
