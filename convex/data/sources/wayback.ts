import { v } from "convex/values";
import { internal } from "../../_generated/api";
import type { Id } from "../../_generated/dataModel";
import { internalAction, internalQuery } from "../../_generated/server";
import { readProductPage } from "./pages";

// Real price history from Internet Archive snapshots of retailer product pages. Each parsed snapshot is one
// observation: source "scrape", provider "wayback", observedAt = snapshot time, url = the snapshot (evidence).
// Free and public, but archive.org asks for gentle use: one request at a time with a pause between them.

const CDX = "https://web.archive.org/cdx/search/cdx";
const UA = "Mozilla/5.0 (compatible; price-history-demo/0.1; hackathon, low rate)";
const PAUSE_MS = 1200;
export const WAYBACK_PROVIDER = "wayback";

export type Snapshot = { timestamp: string; original: string };

// "20260315123000" -> epoch ms (UTC).
export function waybackTime(ts: string): number {
  return Date.UTC(+ts.slice(0, 4), +ts.slice(4, 6) - 1, +ts.slice(6, 8), +ts.slice(8, 10) || 0, +ts.slice(10, 12) || 0, +ts.slice(12, 14) || 0);
}

export const snapshotUrl = (s: Snapshot) => `https://web.archive.org/web/${s.timestamp}id_/${s.original}`;

// CDX JSON is a header row plus one row per capture; we keep one capture per day.
export function parseCdx(json: unknown): Snapshot[] {
  if (!Array.isArray(json) || json.length < 2) return [];
  const [header, ...rows] = json as string[][];
  const ti = header.indexOf("timestamp");
  const oi = header.indexOf("original");
  const byDay = new Map<string, Snapshot>();
  for (const r of rows) {
    const s = { timestamp: r[ti], original: r[oi] };
    if (s.timestamp && s.original && !byDay.has(s.timestamp.slice(0, 8))) byDay.set(s.timestamp.slice(0, 8), s);
  }
  return [...byDay.values()].sort((a, b) => a.timestamp.localeCompare(b.timestamp));
}

// Evenly spaced pick so a capped run still covers the whole period.
export function spread<T>(items: T[], max: number): T[] {
  if (items.length <= max) return items;
  return Array.from({ length: max }, (_, i) => items[Math.round((i * (items.length - 1)) / (max - 1))]);
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function get(url: string) {
  const res = await fetch(url, { headers: { "User-Agent": UA } });
  return { ok: res.ok, status: res.status, text: res.ok ? await res.text() : "" };
}

export const ingestedDays = internalQuery({
  args: { productId: v.id("products"), retailerSlug: v.string() },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("priceObservations")
      .withIndex("by_product_and_retailerSlug_and_observedAt", (q) => q.eq("productId", args.productId).eq("retailerSlug", args.retailerSlug))
      .order("desc")
      .take(2000);
    return rows.filter((r) => r.provider === WAYBACK_PROVIDER).map((r) => new Date(r.observedAt).toISOString().slice(0, 10).replace(/-/g, ""));
  },
});

type IngestResult = {
  snapshots: number;
  fetched: number;
  parsed: number;
  blocked: number;
  recorded: number;
  skippedAlreadyIngested: number;
  failures: string[];
};

// Backfill one product's history at one retailer from archived copies of its product page.
export const ingest = internalAction({
  args: {
    productId: v.id("products"),
    retailer: v.string(),
    url: v.string(),
    from: v.optional(v.string()),
    to: v.optional(v.string()),
    maxSnapshots: v.optional(v.number()),
    pauseMs: v.optional(v.number()),
  },
  handler: async (ctx, args): Promise<IngestResult> => {
    const cdx = new URL(CDX);
    const params: Record<string, string> = {
      url: args.url.replace(/^https?:\/\//, ""),
      matchType: "exact",
      output: "json",
      from: args.from ?? "20251101",
      filter: "statuscode:200",
      collapse: "timestamp:8",
      limit: "2000",
    };
    if (args.to) params.to = args.to;
    for (const [k, val] of Object.entries(params)) cdx.searchParams.set(k, val);
    const list = await get(cdx.toString());
    if (!list.ok) return { snapshots: 0, fetched: 0, parsed: 0, blocked: 0, recorded: 0, skippedAlreadyIngested: 0, failures: [`cdx HTTP ${list.status}`] };
    const all = parseCdx(JSON.parse(list.text || "[]"));
    const done = new Set<string>(await ctx.runQuery(internal.data.sources.wayback.ingestedDays, { productId: args.productId, retailerSlug: args.retailer }));
    const todo = spread(all.filter((s) => !done.has(s.timestamp.slice(0, 8))), Math.min(args.maxSnapshots ?? 40, 60));
    const points: { price?: number; originalPrice?: number; inStock: boolean; observedAt: number; url: string }[] = [];
    const failures: string[] = [];
    let blocked = 0;
    for (const s of todo) {
      await sleep(Math.max(args.pauseMs ?? PAUSE_MS, 0));
      try {
        const page = await get(snapshotUrl(s));
        if (!page.ok) {
          failures.push(`${s.timestamp} HTTP ${page.status}`);
          continue;
        }
        const read = readProductPage(args.retailer, page.text);
        if (read.blocked) blocked++;
        if (read.price !== null) {
          points.push({ price: read.price, originalPrice: read.originalPrice ?? undefined, inStock: true, observedAt: waybackTime(s.timestamp), url: snapshotUrl(s) });
        } else if (read.inStock === false) {
          points.push({ inStock: false, observedAt: waybackTime(s.timestamp), url: snapshotUrl(s) });
        }
      } catch (e) {
        failures.push(`${s.timestamp} ${(e as Error).message.slice(0, 60)}`);
      }
    }
    let recorded = 0;
    for (let i = 0; i < points.length; i += 500) {
      const r: { recorded: number } = await ctx.runMutation(internal.data.prices.recordBatch, {
        productId: args.productId as Id<"products">,
        retailer: args.retailer,
        source: "scrape",
        provider: WAYBACK_PROVIDER,
        points: points.slice(i, i + 500),
      });
      recorded += r.recorded;
    }
    return {
      snapshots: all.length,
      fetched: todo.length - failures.length,
      parsed: points.filter((p) => p.price !== undefined).length,
      blocked,
      recorded,
      skippedAlreadyIngested: all.length - all.filter((s) => !done.has(s.timestamp.slice(0, 8))).length,
      failures: failures.slice(0, 10),
    };
  },
});
