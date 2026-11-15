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

let t: ReturnType<typeof convexTest>;
let ids: Record<string, Id<"products">>;

beforeEach(async () => {
  vi.stubEnv("AGENT_PROVIDER", "fake");
  vi.stubEnv("APP_API_KEY", "");
  vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
  t = convexTest(schema, modules);
  ids = (await t.action(internal.seed.run.all, {})).products as Record<string, Id<"products">>;
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

const scan = (extract: Record<string, unknown>) => t.action(internal.agent.analyze.analyzeScan, { now: SEED_NOW, ...extract });

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
    const good = heuristicAnalysis({ productId: "p", retailer: "target", stats });
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
    const ok = heuristicAnalysis({ productId: "p", retailer: "target", stats: ledger.add("get_price_stats", {}, null) });
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
      const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products"> });
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
    const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products"> });
    expect(report!.product.provisional).toBe(true);
    expect(report!.analysis).toMatchObject({ tier: "full", verdict: "INVESTIGATE" });
  });

  test("the full run uses the tool loop and stores an evidence trail", async () => {
    const r = await scan({ title: "Sony WH-1000XM5", retailer: "Amazon", currentPrice: 249.99 });
    expect(r.reportStatus).toBe("pending");
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products"> });
    expect(report!.analysis!.tier).toBe("full");
    expect(report!.analysis!.groundingIssues).toEqual([]);
    expect(report!.analysis!.evidence[0].tool).toBe("scan");
  });
});

describe("HTTP", () => {
  test("POST /analyze validates input and returns the small contract card", async () => {
    const bad = await t.fetch("/analyze", { method: "POST", body: JSON.stringify({ currentPrice: "cheap" }) });
    expect(bad.status).toBe(400);
    expect(await bad.json()).toHaveProperty("error");
    const res = await t.fetch("/analyze", { method: "POST", body: JSON.stringify({ title: "Zorblax Hyperwidget 9000", retailer: "Target", currentPrice: 20 }) });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Object.keys(body).sort()).toEqual(["confidence", "isSampleData", "productId", "reason", "reportStatus", "verdict"]);
  });

  test("API key is enforced when configured", async () => {
    vi.stubEnv("APP_API_KEY", "k");
    const res = await t.fetch("/analyze", { method: "POST", body: JSON.stringify({ title: "x" }) });
    expect(res.status).toBe(401);
  });

  test("GET /report rejects a bad id with JSON", async () => {
    const res = await t.fetch("/report?productId=nope");
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "productId is not valid" });
  });
});
