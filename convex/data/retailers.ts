// Retailer names as phones and APIs write them, mapped to our slugs.

export const KNOWN_RETAILERS = [
  { slug: "target", name: "Target", domain: "target.com", aliases: ["target"] },
  { slug: "walmart", name: "Walmart", domain: "walmart.com", aliases: ["walmart", "wal-mart"] },
  { slug: "bestbuy", name: "Best Buy", domain: "bestbuy.com", aliases: ["best buy", "bestbuy"] },
  { slug: "amazon", name: "Amazon", domain: "amazon.com", aliases: ["amazon", "amzn"] },
];

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
  return known ? known.slug : cleaned.replace(/\s+/g, "-");
}
