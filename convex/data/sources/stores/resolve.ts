import { v } from "convex/values";
import { internal } from "../../../_generated/api";
import type { Id } from "../../../_generated/dataModel";
import { internalAction, type ActionCtx } from "../../../_generated/server";
import { decideMatch } from "../../../agent/identify";
import { readProductPage } from "../pages";
import { snapshotUrl, waybackTime } from "../wayback";
import { readStructured } from "./structured";
import { parseUrl } from "./url";

// Product link -> catalog product: fetch the store page once (the archived copy when the store blocks us), read
// title, price and "was" price, match the catalog or create a provisional product, and store the price as a
// scrape observation. Background only: the agent schedules it, never awaits it on the live path.

const BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15";
const FETCH_TIMEOUT_MS = 10_000;
const CURRENT_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;
export const STORE_PAGE_PROVIDER = "store-page";

async function fetchText(url: string, headers: Record<string, string>, storePage = false) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(url, { headers, signal: ctl.signal, redirect: storePage ? "manual" : "follow" });
    return res.ok ? await res.text() : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

type Page = { html: string; observedAt: number; via: "live" | "wayback"; evidenceUrl: string };

// Newest archived copies, newest first, for stores that block direct fetches (Lululemon, Adidas).
async function archivedPages(url: string): Promise<{ timestamp: string; original: string }[]> {
  const cdx = new URL("https://web.archive.org/cdx/search/cdx");
  for (const [k, val] of Object.entries({ url: url.replace(/^https?:\/\//, ""), matchType: "exact", output: "json", filter: "statuscode:200", fl: "timestamp,original", limit: "-3" })) cdx.searchParams.set(k, val);
  const text = await fetchText(cdx.toString(), { "User-Agent": BROWSER_UA });
  try {
    const rows = JSON.parse(text ?? "[]") as string[][];
    return rows.slice(1).map(([timestamp, original]) => ({ timestamp, original })).reverse();
  } catch {
    return [];
  }
}

function readPage(retailer: string, html: string, url: string) {
  const price = readProductPage(retailer, html, url);
  const meta = readStructured(html, url);
  return { ...price, title: meta.title, brand: meta.brand };
}

async function loadPage(retailer: string, url: string) {
  const live = await fetchText(url, { "User-Agent": BROWSER_UA, Accept: "text/html,application/xhtml+xml", "Accept-Language": "en-US,en;q=0.9" }, true);
  if (live) {
    const read = readPage(retailer, live, url);
    if (!read.blocked && read.price !== null) return { page: { html: live, observedAt: Date.now(), via: "live", evidenceUrl: url } as Page, read };
  }
  for (const s of await archivedPages(url)) {
    const html = await fetchText(snapshotUrl(s), { "User-Agent": BROWSER_UA });
    if (!html) continue;
    const read = readPage(retailer, html, url);
    if (read.price !== null) return { page: { html, observedAt: waybackTime(s.timestamp), via: "wayback", evidenceUrl: snapshotUrl(s) } as Page, read };
  }
  return null;
}

export type ResolvedUrl = {
  productId?: Id<"products">;
  title?: string;
  retailer?: string;
  currentPrice?: number;
  originalPrice?: number;
  matched?: "catalog" | "created" | "parsed";
  via?: "live" | "wayback";
  observedAt?: number;
} | null;

export async function resolveStoreUrl(ctx: ActionCtx, args: { url: string; title?: string }): Promise<ResolvedUrl> {
  const parsed = parseUrl(args.url);
  if (!parsed) return null;
  const loaded = await loadPage(parsed.retailer, parsed.url);
  const read = loaded?.read;
  const brand = read?.brand ?? undefined;
  // A URL slug alone is too weak to create a product from, so the hint is used only when the page itself loaded.
  let title = read?.title ?? args.title ?? (loaded ? parsed.titleHint : undefined);
  if (title && brand && !title.toLowerCase().includes(brand.toLowerCase())) title = brand + " " + title;
  if (!title) return { retailer: parsed.retailer, matched: "parsed" };
  const variants = [...new URL(parsed.url).searchParams].filter(([key]) => /^(color|sz|size|skuId|variant)$/i.test(key));
  if (variants.length) title += " " + variants.map(([key, value]) => key + " " + value).join(" ");
  const fresh = loaded && Date.now() - loaded.page.observedAt < CURRENT_WINDOW_MS;
  const price = read?.inStock === false ? undefined : (read?.price ?? undefined);
  const result: NonNullable<ResolvedUrl> = {
    title,
    retailer: parsed.retailer,
    currentPrice: fresh ? price : undefined,
    originalPrice: fresh ? (read?.originalPrice ?? undefined) : undefined,
    matched: "parsed",
    via: loaded?.page.via,
    observedAt: loaded?.page.observedAt,
  };
  const decision = decideMatch(await ctx.runQuery(internal.data.catalog.matchProduct, { title, limit: 6 }));
  const variantMatches = decision.kind === "match" && (variants.length ? decision.candidate.product.title === title : (
    decision.candidate.product.model === parsed.productCode ||
    Object.values(decision.candidate.product.variant ?? {}).every((part) => title!.toLowerCase().includes(part.toLowerCase()))
  ));
  if (decision.kind === "match" && variantMatches) {
    result.productId = decision.candidate.product._id;
    result.matched = "catalog";
  } else if ((decision.kind === "none" || (decision.kind === "match" && !variantMatches)) && price !== undefined) {
    if (decision.kind === "match" && parsed.productCode) title = result.title = title + " " + parsed.productCode;
    result.productId = await ctx.runMutation(internal.data.catalog.createProvisionalProduct, { title, brand });
    result.matched = "created";
  }
  if (result.productId && loaded && price !== undefined) {
    await ctx.runMutation(internal.data.prices.recordObservation, {
      productId: result.productId,
      retailer: parsed.retailer,
      price,
      inStock: true,
      originalPrice: read?.originalPrice ?? undefined,
      observedAt: loaded.page.observedAt,
      source: "scrape",
      provider: loaded.page.via === "live" ? STORE_PAGE_PROVIDER : "wayback",
      url: loaded.page.evidenceUrl,
    });
  }
  return result;
}

export const resolveUrl = internalAction({
  args: { url: v.string(), title: v.optional(v.string()), retailer: v.optional(v.string()) },
  returns: v.union(v.null(), v.object({
    productId: v.optional(v.id("products")), title: v.optional(v.string()), retailer: v.optional(v.string()),
    currentPrice: v.optional(v.number()), originalPrice: v.optional(v.number()),
    matched: v.optional(v.union(v.literal("catalog"), v.literal("created"), v.literal("parsed"))),
    via: v.optional(v.union(v.literal("live"), v.literal("wayback"))), observedAt: v.optional(v.number()),
  })),
  handler: (ctx, args): Promise<ResolvedUrl> => resolveStoreUrl(ctx, args),
});
