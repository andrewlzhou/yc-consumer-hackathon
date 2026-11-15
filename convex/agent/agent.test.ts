import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import schema from "../schema";
import { SEED_NOW } from "../seed/generate";
import { modules } from "../test.setup";
import { checkGrounding, EvidenceLedger, numberMatches } from "./evidence";
import { heuristicAnalysis } from "./heuristic";
import { parseAgentOutput } from "./output";
import { present } from "./port";
import { COMPETITOR_TOOLS } from "./tools";
import rateLimiterTest from "@convex-dev/rate-limiter/test";

let t: ReturnType<typeof convexTest>;
let ids: Record<string, Id<"products">>;

beforeEach(async () => {
  vi.stubEnv("AGENT_PROVIDER", "fake");
  vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
  t = convexTest(schema, modules);
  rateLimiterTest.register(t);
  ids = (await t.action(internal.seed.run.all, {})).products as Record<string, Id<"products">>;
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

const scan = async (extract: Record<string, unknown>) => {
  const r = await t.action(internal.agent.analyze.analyzeScan, { now: SEED_NOW, ...extract });
  return { ...r.response, path: r.path };
};
const post = (body: unknown, headers: Record<string, string> = {}) => t.fetch("/analyze", { method: "POST", body: JSON.stringify(body), headers });

describe("grounding", () => {
  test("numbers match with display rounding and percents, not invented ones", () => {
    expect(numberMatches(200, 199.99)).toBe(true);
    expect(numberMatches(23, 23.4)).toBe(true);
    expect(numberMatches(12, 0.12)).toBe(true);
    expect(numberMatches(150, 149)).toBe(false);
  });

  test("present() turns timestamps into dates and fractions into percents", () => {
    expect(present({ startAt: Date.UTC(2026, 10, 27), vsMedianPct: -0.278, percentile: 0.05, price: 179.99 })).toEqual({
      startAt: "2026-11-27",
      vsMedianPercent: -27.8,
      percentileRankPercent: 5,
      price: 179.99,
    });
  });

  test("flags invented numbers, unknown citations, and invented competitors", () => {
    const ledger = new EvidenceLedger();
    const stats = ledger.add("get_price_stats", { productId: "p" }, { overall: { observationCount: 40, prices: { median: 249, min: 179, spanDays: 300, latest: { price: 179.99, retailerSlug: "target" }, minLastSeenAt: "2026-06-26", mean: 240 }, current: { price: 179.99, percentileRankPercent: 3, vsMedianPercent: -27.7, vsMinPercent: 0.6, atOrBelowLow: false } }, perRetailer: [], wasPrice: null });
    const good = heuristicAnalysis({ productId: "p", retailer: "target", stats, today: "2026-11-15" });
    expect(checkGrounding(good, ledger, COMPETITOR_TOOLS)).toEqual([]);
    const bad = { ...good, reason: "Down to $149 from $249.", reasonEvidenceIds: ["E1"], competitors: [{ productId: "x", title: "Made Up", valueReasoning: "cheaper", evidenceIds: ["E9"] }] };
    const issues = checkGrounding(bad, ledger, COMPETITOR_TOOLS);
    expect(issues.join("\n")).toMatch(/reason: numbers 149/);
    expect(issues.join("\n")).toMatch(/unknown evidence E9/);
    expect(issues.join("\n")).toMatch(/competitor x does not appear/);
  });

  test("schema validation rejects missing fields and out-of-range confidence", () => {
    expect(parseAgentOutput("{}").ok).toBe(false);
    const ledger = new EvidenceLedger();
    const ok = heuristicAnalysis({ productId: "p", retailer: "target", stats: ledger.add("get_price_stats", {}, null), today: "2026-11-15" });
    expect(parseAgentOutput(JSON.stringify(ok)).ok).toBe(true);
    expect(parseAgentOutput(JSON.stringify({ ...ok, confidence: 2 })).ok).toBe(false);
  });
});

describe("live scans of seeded products (fake provider)", () => {
  const cases: [string, Record<string, unknown>, string][] = [
    ["airpods", { title: "Apple AirPods Pro 3 Wireless Earbuds", retailer: "Walmart", currentPrice: 179.99, originalPrice: 249 }, "BUY_NOW"],
    ["ipad 128", { title: "Apple iPad 11-inch A16 Wi-Fi 128GB", retailer: "Target", currentPrice: 449 }, "WAIT"],
    ["ninja", { title: "Ninja AF101 Air Fryer 4 Quart", retailer: "Target", currentPrice: 74.99, originalPrice: 99.99 }, "WAIT"],
    ["bose", { title: "Bose QuietComfort Ultra Headphones (2nd Gen)", retailer: "Best Buy", currentPrice: 399, originalPrice: 449 }, "CONSIDER_ALTERNATIVE"],
    ["ember", { title: "Ember Mug 2 Smart Mug 10 oz", retailer: "Amazon", currentPrice: 99.95 }, "INVESTIGATE"],
  ];
  for (const [name, extract, verdict] of cases)
    test(`${name} -> ${verdict}`, async () => {
      const r = await scan(extract);
      expect(r.verdict).toBe(verdict);
      expect(r.productId).toBeDefined();
      expect(r.isSampleData).toBe(true);
      expect(r.reason).toMatch(/\(sample data\)$/);
      const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products">, now: SEED_NOW });
      expect(report!.analysis!.groundingIssues).toEqual([]);
      expect(report!.analysis!.evidence.map((e: { tool: string }) => e.tool)).toEqual(expect.arrayContaining(["scan", "get_price_stats", "get_promo_patterns", "find_competitors"]));
    });

  test("the 256GB iPad is not confused with the 128GB one", async () => {
    const r = await scan({ title: "Apple iPad 11-inch (A16) Wi-Fi 256GB", retailer: "Target", currentPrice: 549 });
    expect(r.productId).toBe(ids["ipad-a16-256"]);
  });

  test("an OCR-mangled title still matches", async () => {
    const r = await scan({ title: "Ninja AFl0l Air Fryer 4-Quart", retailer: "Target", currentPrice: 74.99 });
    expect(r.productId).toBe(ids["ninja-af101"]);
  });

  test("a second scan at the same price is served from the stored analysis", async () => {
    await scan({ title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 179.99 });
    const again = await scan({ title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 179.99 });
    expect(again.path).toBe("cache");
    expect(again.reportStatus).toBe("pending");
  });

  test("the scan price is recorded as an observation", async () => {
    await scan({ title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 189.5 });
    const rows = await t.run((ctx) => ctx.db.query("priceObservations").filter((q) => q.eq(q.field("source"), "scan")).collect());
    expect(rows.map((r) => r.price)).toEqual([189.5]);
  });
});

describe("unknown products and the background run", () => {
  test("an unknown product returns INVESTIGATE fast and queues a full analysis", async () => {
    const r = await scan({ title: "Zorblax Hyperwidget 9000 Turbo", retailer: "Target", currentPrice: 59.99 });
    expect(r).toMatchObject({ verdict: "INVESTIGATE", path: "unknown", reportStatus: "pending" });
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products">, now: SEED_NOW });
    expect(report!.product.provisional).toBe(true);
    expect(report!.analysis).toMatchObject({ tier: "full", verdict: "INVESTIGATE" });
  });

  test("the full run is one prefetched pass and stores an evidence trail", async () => {
    const r = await scan({ title: "Sony WH-1000XM5", retailer: "Amazon", currentPrice: 249.99 });
    expect(r.reportStatus).toBe("pending");
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products">, now: SEED_NOW });
    expect(report!.analysis!.tier).toBe("full");
    expect(report!.analysis!.groundingIssues).toEqual([]);
    expect(report!.analysis!.evidence[0].tool).toBe("scan");
    expect(report!.analysis!.evidence.map((e: { tool: string }) => e.tool)).toEqual(expect.arrayContaining(["key_facts", "insights", "price_sources"]));
  });

  test("an unknown product's full run tries the real-data lookup (skipped without a SerpApi key)", async () => {
    const r = await scan({ title: "Zorblax Hyperwidget 9000 Turbo", retailer: "Target", currentPrice: 59.99 });
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products">, now: SEED_NOW });
    const sources = report!.analysis!.evidence.find((e: { tool: string }) => e.tool === "price_sources");
    expect(sources!.result).toMatchObject({ realDataLookup: "no_key" });
  });
});

describe("HTTP", () => {
  test("POST /analyze validates input and returns the small contract card", async () => {
    const bad = await post({ deviceId: "d1", currentPrice: "cheap" });
    expect(bad.status).toBe(400);
    expect(await bad.json()).toHaveProperty("error");
    const res = await post({ deviceId: "d1", title: "Zorblax Hyperwidget 9000", retailer: "Target", currentPrice: 20 });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Object.keys(body).sort()).toEqual(["confidence", "isSampleData", "productId", "reason", "reportStatus", "verdict"]);
  });

  test("regression H2: routes fail closed without APP_API_KEY unless explicitly opened", async () => {
    vi.stubEnv("APP_ALLOW_UNAUTHENTICATED", "");
    expect((await post({ deviceId: "d1", title: "x" })).status).toBe(401);
    expect((await t.fetch("/watchlist?deviceId=d1")).status).toBe(401);
    vi.stubEnv("APP_API_KEY", "secret-key");
    expect((await post({ deviceId: "d1", title: "x" }, { "x-api-key": "wrong-key!" })).status).toBe(401);
    expect((await post({ deviceId: "d1", title: "Zorblax" }, { "x-api-key": "secret-key" })).status).toBe(200);
  });

  test("regression H2: /analyze requires a deviceId and rate-limits each device", async () => {
    expect((await post({ title: "Zorblax" })).status).toBe(400);
    const statuses: number[] = [];
    for (let i = 0; i < 12; i++) statuses.push((await post({ deviceId: "spammer", title: "Zorblax Hyperwidget" })).status);
    expect(statuses.slice(0, 10).every((s) => s === 200)).toBe(true);
    expect(statuses.at(-1)).toBe(429);
    expect((await post({ deviceId: "someone-else", title: "Zorblax Hyperwidget" })).status).toBe(200);
  });

  test("GET /report rejects a bad id with JSON and returns the contract shape", async () => {
    const res = await t.fetch("/report?productId=nope");
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "productId is not valid" });
    const r = await scan({ title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 179.99 });
    const ok = await t.fetch(`/report?productId=${r.productId}`);
    expect(ok.status).toBe(200);
    expect((await ok.json()).analysis.report.verdict).toBe(r.verdict);
  });
});

describe("monitoring hook", () => {
  test("regression H1: the analysis handed to monitoring carries isSampleData", async () => {
    await scan({ title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 179.99 });
    const snap = await t.action(internal.monitoring.ports.getSnapshot, { productId: ids["airpods-pro-3"] });
    expect(snap!.snapshot.isSampleData).toBe(true);
  });
});
