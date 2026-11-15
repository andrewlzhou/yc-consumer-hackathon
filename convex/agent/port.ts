import { internal } from "../_generated/api";
import type { ActionCtx } from "../_generated/server";
import type { Id } from "../_generated/dataModel";
import { hybridSearch } from "../data/embeddings";
import type { productView } from "../data/catalog";

type ProductView = ReturnType<typeof productView>;

const DAY = 86_400_000;
const isDateKey = (k: string) => /At$/.test(k) || k === "from" || k === "to";
const isFractionKey = (k: string) => /Pct$/.test(k) || /[sS]hare/.test(k) || k === "percentile";
const percentKey = (k: string) => (k === "percentile" ? "percentileRankPercent" : k.replace(/Pct$/, "Percent").replace(/(Share\w*|share\w*)$/, "$1Percent"));

// Shapes data-thread results for the model: epoch timestamps become ISO dates and 0-1 fractions become percents,
// so the model never converts units itself and every date or percent it writes appears verbatim in evidence.
export function present(value: unknown, key = ""): unknown {
  if (typeof value === "number") {
    if (isDateKey(key) && value > 1e11) return new Date(value).toISOString().slice(0, 10);
    if (isFractionKey(key)) return Math.round(value * 1000) / 10;
    return value;
  }
  if (Array.isArray(value)) return value.map((v) => present(v, key));
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) {
      if (k === "_creationTime" || k === "embedding") continue;
      out[typeof v === "number" && isFractionKey(k) ? percentKey(k) : k] = present(v, k);
    }
    return out;
  }
  return value;
}

const id = (productId: string) => productId as Id<"products">;

// Every data read the agent makes, over the data thread's internal functions, with results presented for the model.
export function dataPort(ctx: ActionCtx, now: number) {
  let sample = false;
  const track = <T>(value: T): T => {
    if (value && typeof value === "object" && (value as { isSampleData?: boolean }).isSampleData) sample = true;
    return value;
  };
  return {
    now,
    sampleDataSeen: () => sample,
    matchProduct: (title: string, limit = 6) => ctx.runQuery(internal.data.catalog.matchProduct, { title, limit }),
    hybridMatch: (title: string) => hybridSearch(ctx, title, { limit: 6 }),
    searchCatalog: async (query: string) => present(await ctx.runQuery(internal.data.catalog.matchProduct, { title: query, limit: 6 })),
    product: (productId: string): Promise<ProductView | null> => ctx.runQuery(internal.data.catalog.getProduct, { productId: id(productId) }),
    stats: async (productId: string, o: { retailer?: string; days?: number; currentPrice?: number; originalPrice?: number }) =>
      present(track(await ctx.runQuery(internal.data.prices.getPriceStats, { productId: id(productId), now, windowDays: o.days ?? 365, retailerSlug: o.retailer, currentPrice: o.currentPrice, originalPrice: o.originalPrice }))),
    promo: async (productId: string, retailer?: string) =>
      present(track(await ctx.runQuery(internal.data.prices.findPromoPatterns, { productId: id(productId), now, windowDays: 365, retailerSlug: retailer }))),
    history: async (productId: string, retailer: string | undefined, days: number) => {
      const { points, truncated } = await ctx.runQuery(internal.data.prices.getPriceHistory, { productId: id(productId), retailerSlug: retailer, from: now - days * DAY, to: now, limit: 1500 });
      const priced = points.filter((p) => p.inStock && p.price !== undefined);
      const step = Math.max(1, Math.ceil(priced.length / 60));
      const sampled = priced.filter((_, i) => i % step === 0 || i === priced.length - 1);
      return present({ pointCount: priced.length, shownCount: sampled.length, truncated, points: sampled.map((p) => ({ observedAt: p.observedAt, retailerSlug: p.retailerSlug, price: p.price, originalPrice: p.originalPrice ?? null, source: p.source })) });
    },
    // Where the stored prices come from (seed, Wayback snapshots, SerpApi, scans), with a few example source URLs.
    priceSources: async (productId: string, days: number) => {
      const { points, truncated } = await ctx.runQuery(internal.data.prices.getPriceHistory, { productId: id(productId), from: now - days * DAY, to: now, limit: 3000 });
      const groups = new Map<string, { source: string; provider: string | null; observationCount: number; firstObservedAt: number; lastObservedAt: number; exampleUrls: string[] }>();
      for (const p of points) {
        const key = `${p.source}/${p.provider ?? ""}`;
        const g = groups.get(key) ?? { source: p.source, provider: p.provider ?? null, observationCount: 0, firstObservedAt: p.observedAt, lastObservedAt: p.observedAt, exampleUrls: [] };
        g.observationCount++;
        g.lastObservedAt = Math.max(g.lastObservedAt, p.observedAt);
        if (p.url && g.exampleUrls.length < 3 && !g.exampleUrls.includes(p.url)) g.exampleUrls.push(p.url);
        groups.set(key, g);
      }
      return present({ observationCount: points.length, truncated, sources: [...groups.values()].sort((a, b) => b.observationCount - a.observationCount) }) as Record<string, unknown>;
    },
    calendar: async (days: number) => present(await ctx.runQuery(internal.data.calendar.getSaleCalendar, { from: now, to: now + days * DAY })),
    digest: async (productId: string) => present(await ctx.runQuery(internal.data.digests.getDigest, { productId: id(productId) })),
    comparables: async (productId: string, limit = 5) => {
      const similar = await ctx.runAction(internal.data.embeddings.findSimilarProducts, { productId: id(productId), limit });
      return Promise.all(
        similar.products.map(async ({ product: p, similarity }) => {
          const s = track(await ctx.runQuery(internal.data.prices.getPriceStats, { productId: p._id, now, windowDays: 90 }));
          const prices = s.overall.prices;
          return {
            productId: p._id as string,
            title: p.title,
            brand: p.brand,
            specs: p.specs,
            isSample: p.isSample,
            similarity,
            last90Days: { observationCount: s.overall.observationCount, latestPrice: prices?.latest.price ?? null, latestRetailer: prices?.latest.retailerSlug ?? null, median: prices?.median ?? null, min: prices?.min ?? null },
          };
        }),
      );
    },
  };
}

export type DataPort = ReturnType<typeof dataPort>;
