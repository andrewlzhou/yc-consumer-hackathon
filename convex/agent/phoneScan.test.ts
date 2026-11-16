import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import rateLimiterTest from "@convex-dev/rate-limiter/test";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import schema from "../schema";
import { SEED_NOW } from "../seed/generate";
import { SEED_PRODUCTS } from "../seed/catalog";
import { DEMO_PRODUCTS } from "../data/demo";
import { modules } from "../test.setup";
import xm5 from "../data/sources/fixtures/serpapi-product-xm5.json";
import pages from "../data/sources/stores/fixtures/store-pages.json";
import { checkCard, EvidenceLedger, relationIssues } from "./evidence";
import { keyFacts } from "./facts";
import { usableTitle } from "./screenText";
import { expandShortLink, isAmazonShortLink } from "./urls";

// Regressions from real iPhone 14 scans (YCCO-10) and the iOS review (YCCO-11 H3): CON-10 and CON-11.

let t: ReturnType<typeof convexTest>;
let ids: Record<string, Id<"products">>;
const notFound = () => vi.fn(async (_url: string | URL, _init?: RequestInit) => new Response("", { status: 404 }));

beforeEach(async () => {
  vi.stubEnv("AGENT_PROVIDER", "fake");
  vi.stubGlobal("fetch", notFound());
  vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
  t = convexTest(schema, modules);
  rateLimiterTest.register(t);
  ids = (await t.action(internal.seed.run.all, {})).products as Record<string, Id<"products">>;
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

const scan = async (extract: Record<string, unknown>) => {
  const r = await t.action(internal.agent.analyze.analyzeScan, { now: SEED_NOW, deviceId: "phone-1", ...extract });
  return { ...r.response, path: r.path, latencyMs: r.latencyMs, timings: r.timings };
};
const settle = () => t.finishAllScheduledFunctions(vi.runAllTimers);
const productCount = () => t.run(async (ctx) => (await ctx.db.query("products").collect()).length);
type StoredAnalysis = { productId: string; tier: string; groundingIssues: string[]; evidence: { tool: string; result: string }[] };
const liveAnalysis = async (productId: Id<"products">) => {
  const rows = (await t.run((ctx) => ctx.db.query("analyses").collect())) as StoredAnalysis[];
  return rows.filter((a) => a.productId === productId && a.tier === "live").at(-1);
};

// A stand-in for the OpenAI Responses API that always answers the live card with the given reason.
function openAiAnswering(reason: string) {
  vi.stubEnv("AGENT_PROVIDER", "");
  vi.stubEnv("OPENAI_API_KEY", "test-key");
  const fetchMock = vi.fn(async (url: string | URL) => {
    if (!String(url).includes("/v1/responses")) return new Response("", { status: 404 });
    const card = { verdict: "BUY_NOW", confidence: 0.8, reason, reasonEvidenceIds: [] };
    return new Response(JSON.stringify({ output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(card) }] }], usage: { input_tokens: 1, output_tokens: 1 } }));
  });
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

describe("XM5 at $179 on Amazon: price relations in the reason must hold", () => {
  const XM5_REASON = "$179 is a new low, within 3% of the lowest observed $198; past BF sales did not beat it.";

  test("the exact phone reason is rejected: $179 is 9.6% below $198, not within 3%", () => {
    expect(relationIssues(XM5_REASON)).toEqual([expect.stringMatching(/within 3% of.*\$179 and \$198.*differ by 9\.6%/)]);
  });

  test("true relations pass, false ones fail", () => {
    for (const ok of ["$198 is 29% under the typical $278.", "$179.99 is 0.6% above the lowest $179.", "Black Friday's $29.97 is 16.7% below today's $35.97.", "Today's $35.97 is 20% above the $29.97 low.", "$179.99 matches the low of $179.99.", "$179 is below the lowest we've recorded ($198)."])
      expect(relationIssues(ok)).toEqual([]);
    expect(relationIssues("$250 is 10% below $200.")[0]).toMatch(/direction is wrong/);
    expect(relationIssues("$179 matches the low of $198.")[0]).toMatch(/differ by 9\.6%/);
    expect(relationIssues("$90 is 40% below $100.")[0]).toMatch(/gap is 10%/);
  });

  test("key_facts label a scan below every recorded price as below, never within 3%", () => {
    const ledger = new EvidenceLedger();
    const summary = { observationCount: 49, prices: { median: 278, min: 198, minLastSeenAt: "2026-11-14", spanDays: 365, latest: { price: 198, retailerSlug: "bestbuy", observedAt: "2026-11-15" } }, current: { price: 179 } };
    const stats = ledger.add("get_price_stats", { productId: "p", currentPrice: 179 }, { overall: summary, perRetailer: [], wasPrice: null, isSampleData: false });
    const promo = ledger.add("get_promo_patterns", {}, { claimedDiscounts: [], upcoming: [], recurrence: { episodeCount: 0, medianGapDays: null } });
    const facts = keyFacts("amazon", stats, stats, promo, ledger.add("find_competitors", {}, []));
    expect(facts).toMatchObject({ currentPriceSource: "scan", priceVsLowest: "below_lowest_recorded", currentVsLowestPercent: -9.6, currentMinusLowest: -19 });
    ledger.add("key_facts", {}, facts);
    expect(checkCard({ reason: XM5_REASON, reasonEvidenceIds: [] }, ledger).issues.join("\n")).toMatch(/within 3%/);
    expect(relationIssues("$198 is a new low.", ledger)).toEqual([]);
  });

  // Real Google history for the XM5 (lowest $198), then the phone's Amazon scan at $179 with a model that repeats
  // the false relation: the card falls back to the deterministic analyst and says what is true.
  async function realXm5() {
    vi.useFakeTimers({ now: SEED_NOW, toFake: ["Date", "setTimeout", "clearTimeout"] });
    vi.stubEnv("SERPAPI_API_KEY", "test-key");
    vi.stubEnv("OPENAI_API_KEY", "");
    vi.stubGlobal("fetch", vi.fn(async () => new Response(JSON.stringify(xm5))));
    await t.action(internal.data.demo.ingest, { key: "sony-xm5", wayback: false });
    vi.stubEnv("SERPAPI_API_KEY", "");
  }

  test("regression: the phone's $179 scan never shows 'within 3% of $198'", async () => {
    await realXm5();
    const model = openAiAnswering(XM5_REASON);
    const card = await scan({ title: "Sony WH-1000XM5 Wireless Noise Canceling Headphones", retailer: "Amazon", currentPrice: 179 });
    expect(card.productId).toBe(ids["sony-xm5"]);
    expect(model).toHaveBeenCalledTimes(2);
    expect(card.path).toBe("heuristic");
    expect(card.reason).not.toMatch(/within 3%/);
    expect(card.reason).toMatch(/^\$179\.00 is 9\.6% below the lowest price we've recorded \(\$198\.00\)/);
    expect(relationIssues(card.reason)).toEqual([]);
    const stored = await liveAnalysis(ids["sony-xm5"]);
    expect(stored!.groundingIssues.join("\n")).toMatch(/within 3% of.*differ by 9\.6%/);
    expect(stored!.groundingIssues.filter((i) => i.startsWith("heuristic:"))).toEqual([]);
    const facts = JSON.parse(stored!.evidence.find((e) => e.tool === "key_facts")!.result);
    expect(facts).toMatchObject({ currentPriceSource: "scan", priceVsLowest: "below_lowest_recorded", lowestPrice: 198 });
  });

  test("a correct model reason for the same scan is kept", async () => {
    await realXm5();
    openAiAnswering("$179 is below the lowest we've recorded ($198), and past Black Friday sales did not beat it.");
    const card = await scan({ title: "Sony WH-1000XM5 Wireless Noise Canceling Headphones", retailer: "Amazon", currentPrice: 179 });
    expect(card).toMatchObject({ path: "live", verdict: "BUY_NOW" });
  });
});

describe("AE Baggy Jean link: variant boundaries", () => {
  const AE_914 = "https://www.ae.com/us/en/p/men/jeans/baggy-loose-jeans/ae-baggy-jean/1114_7364_914";
  const snapshot = "20260612053542";

  test("color 914's link never shows the tracked Black 33x32 history, and the live path fetches nothing", async () => {
    const { productId: black } = await t.mutation(internal.data.demo.ensureDemoProduct, { key: "ae-baggy-jean" });
    const fetchMock = notFound();
    vi.stubGlobal("fetch", fetchMock);
    const linkOnly = await scan({ url: AE_914 });
    expect(linkOnly).toMatchObject({ verdict: "INVESTIGATE", reportStatus: "pending", path: "unknown" });
    expect(linkOnly.productId).toBeUndefined();
    expect(linkOnly.timings).not.toHaveProperty("model");
    const titled = await scan({ url: AE_914, title: "AE Baggy Jean", retailer: "American Eagle", currentPrice: 35.97 });
    expect(titled.productId).not.toBe(black);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("after background resolution the link gets its own product and an honest INVESTIGATE", async () => {
    const { productId: black } = await t.mutation(internal.data.demo.ensureDemoProduct, { key: "ae-baggy-jean" });
    vi.stubGlobal("fetch", vi.fn(async (url: string) => {
      if (url.includes("/cdx/")) return new Response(JSON.stringify([["timestamp", "original"], [snapshot, AE_914]]));
      if (url.includes(snapshot + "id_/")) return new Response(pages.aeBaggy);
      return new Response("Access Denied", { status: 403 });
    }));
    await scan({ url: AE_914 });
    await settle();
    const card = await scan({ url: AE_914 });
    expect(card.productId).toBeDefined();
    expect(card.productId).not.toBe(black);
    expect(card.matchedTitle).toMatch(/1114_7364_914/);
    expect(card.verdict).toBe("INVESTIGATE");
    expect(card.reason).toMatch(/only 1 price for this exact item \(latest \$24\.99 on 2026-06-12\)/);
  });

  test("a Nike link keeps the title match only when its style-color is the catalog model", async () => {
    const { productId: zenvy } = await t.mutation(internal.data.demo.ensureDemoProduct, { key: "nike-zenvy-leggings" });
    const base = "https://www.nike.com/t/zenvy-womens-high-waisted-full-length-leggings-with-no-front-seam-PrjzuxGX/";
    const title = "Nike Zenvy Women's High-Waisted Full-Length Leggings";
    expect((await scan({ url: base + "II2862-010", title, retailer: "Nike", currentPrice: 105 })).productId).toBe(zenvy);
    expect((await scan({ url: base + "II2862-011", title, retailer: "Nike", currentPrice: 105 })).productId).not.toBe(zenvy);
  });
});

describe("Amazon links", () => {
  const XM5_DP = "https://www.amazon.com/dp/B09XS7JWHH";

  test("a /dp/ link matches the catalog product by exact ASIN, with no page fetch", async () => {
    const fetchMock = notFound();
    vi.stubGlobal("fetch", fetchMock);
    const card = await scan({ url: XM5_DP });
    expect(card.productId).toBe(ids["sony-xm5"]);
    expect(card.verdict).not.toBe("INVESTIGATE");
    await settle();
    expect(fetchMock).not.toHaveBeenCalled();
    expect((await scan({ url: "https://www.amazon.com/Sony-WH-1000XM5/dp/B09XS7JWHH?ref=abc&th=1" })).productId).toBe(ids["sony-xm5"]);
  });

  test("an unknown ASIN that cannot be resolved says so about the link, never about reading the screen", async () => {
    const first = await scan({ url: "https://www.amazon.com/dp/B0UNKNOWN1" });
    expect(first).toMatchObject({ verdict: "INVESTIGATE", reportStatus: "pending" });
    await settle();
    const again = await scan({ url: "https://www.amazon.com/dp/B0UNKNOWN1" });
    expect(again).toMatchObject({ verdict: "INVESTIGATE", reportStatus: "none" });
    expect(again.reason).toMatch(/from its link/);
    expect(again.reason).not.toMatch(/screen/);
  });

  test("an a.co share link is expanded in the background to its ASIN", async () => {
    const fetchMock = vi.fn(async (url: string | URL) =>
      String(url) === "https://a.co/d/7xYz9Q1" ? new Response(null, { status: 301, headers: { location: "https://www.amazon.com/dp/B09XS7JWHH?ref_=cm_sw_r_apan" } }) : new Response("", { status: 404 }));
    vi.stubGlobal("fetch", fetchMock);
    expect(await scan({ url: "https://a.co/d/7xYz9Q1" })).toMatchObject({ verdict: "INVESTIGATE", reportStatus: "pending" });
    expect(fetchMock).not.toHaveBeenCalled();
    await settle();
    expect(fetchMock.mock.calls.map(([u]) => String(u))).toEqual(["https://a.co/d/7xYz9Q1"]);
    expect((await scan({ url: "https://a.co/d/7xYz9Q1" })).productId).toBe(ids["sony-xm5"]);
  });

  test("short links only expand into Amazon over https, with bounded hops", async () => {
    const redirect = (location: string) => vi.fn(async () => new Response(null, { status: 302, headers: { location } }));
    expect(await expandShortLink("https://amzn.to/3abcDEF", redirect("https://www.amazon.com/gp/product/B09XS7JWHH"))).toBe("https://www.amazon.com/dp/B09XS7JWHH");
    expect(await expandShortLink("https://amzn.to/3abcDEF", redirect("http://www.amazon.com/dp/B09XS7JWHH?tag=x"))).toBe("https://www.amazon.com/dp/B09XS7JWHH");
    expect(await expandShortLink("https://amzn.to/3abcDEF", redirect("http://www.amazon.com/"))).toBeNull();
    for (const bad of ["https://evil.example/dp/B09XS7JWHH", "http://169.254.169.254/latest/meta-data", "https://www.amazon.com.evil.example/dp/B09XS7JWHH", "https://user:pw@www.amazon.com/dp/B09XS7JWHH", "https://www.amazon.com/gp/help"])
      expect(await expandShortLink("https://a.co/d/abc123", redirect(bad))).toBeNull();
    const loop = redirect("https://a.co/d/abc123");
    expect(await expandShortLink("https://a.co/d/abc123", loop)).toBeNull();
    expect(loop).toHaveBeenCalledTimes(3);
    const never = vi.fn();
    for (const raw of ["https://a.co.evil.example/d/abc123", "https://a.co:8443/d/abc123", "https://evil.example/d/abc123"]) {
      expect(isAmazonShortLink(raw)).toBe(false);
      expect(await expandShortLink(raw, never)).toBeNull();
    }
    expect(never).not.toHaveBeenCalled();
  });
});

describe("OCR-only and personal screen text (CON-10)", () => {
  const notProducts: [string, Record<string, unknown>][] = [
    ["notification banner as OCR lines", { ocrLines: ["Messages now", "Mom: are you picking up Sam at 5 today", "$24.99"], currentPrice: 24.99, retailer: "Target" }],
    ["account header as OCR lines", { ocrLines: ["Hello, Ruhaan Singh", "1600 Amphitheatre Pkwy apt 4", "Deliver to Ruhaan - Anytown 00000"], currentPrice: 49.99 }],
    ["unknown product from OCR lines only", { ocrLines: ["Zorblax Hyperwidget 9000 Turbo", "$59.99"], currentPrice: 59.99, retailer: "Target" }],
    ["notification banner as the title", { title: "Messages now Mom: are you picking up Sam at 5 today", currentPrice: 24.99, retailer: "Target" }],
    ["account header as the title", { title: "Hello, Ruhaan Singh 1600 Amphitheatre Pkwy apt 4", currentPrice: 24.99 }],
    ["store home screen as the title", { title: "Best Buy App", retailer: "Best Buy", currentPrice: 9.99 }],
  ];
  for (const [name, extract] of notProducts)
    test(`${name}: INVESTIGATE, no product, no stored text, no paid call`, async () => {
      vi.stubEnv("AGENT_PROVIDER", "");
      vi.stubEnv("OPENAI_API_KEY", "test-key");
      vi.stubEnv("SERPAPI_API_KEY", "test-key");
      const fetchMock = vi.fn(async () => new Response("", { status: 500 }));
      vi.stubGlobal("fetch", fetchMock);
      const before = await productCount();
      const card = await scan(extract);
      await settle();
      expect(card).toMatchObject({ verdict: "INVESTIGATE", reportStatus: "none" });
      expect(card.productId).toBeUndefined();
      expect(await productCount()).toBe(before);
      expect(fetchMock).not.toHaveBeenCalled();
      const rows = await t.run((ctx) => ctx.db.query("agentScans").collect());
      expect(rows).toHaveLength(1);
      expect(rows[0].title).toBeUndefined();
      const prices = await t.run((ctx) => ctx.db.query("priceObservations").filter((q) => q.eq(q.field("source"), "scan")).collect());
      expect(prices).toEqual([]);
    });

  test("OCR lines that clearly name a catalog product still match, without the banner reaching the analysis", async () => {
    const card = await scan({ ocrLines: ["Messages now Mom: are you there", "Sony WH-1000XM5 Wireless Noise Canceling Over-Ear Headphones", "$248.00"], retailer: "Best Buy", currentPrice: 248 });
    expect(card.productId).toBe(ids["sony-xm5"]);
    const stored = await liveAnalysis(ids["sony-xm5"]);
    expect(JSON.stringify(stored!.evidence)).not.toMatch(/Mom|Messages/);
    const rows = await t.run((ctx) => ctx.db.query("agentScans").collect());
    expect(rows[0].title).toBeUndefined();
  });

  test("real product titles and aliases are never treated as screen chrome or personal text", () => {
    const titles = [...SEED_PRODUCTS, ...DEMO_PRODUCTS].flatMap((p) => [p.title, ...p.aliases]);
    titles.push("Amazon Echo Dot (5th Gen) Smart Speaker", "Best Buy Essentials 6ft HDMI Cable", "Apple AirPods Pro 3", "Target Up&Up Cotton Rounds 100 ct", "Nike Pegasus 42 Men's Road Running Shoes");
    expect(titles.filter((x) => usableTitle(x) === null)).toEqual([]);
    for (const chrome of ["Best Buy App", "Amazon", "walmart.com", "Target Home", "Shop Nike", "Apple Store"]) expect(usableTitle(chrome)).toBeNull();
  });
});
