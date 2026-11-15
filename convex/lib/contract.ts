import { v, type Infer } from "convex/values";

// Phone <-> backend contract. The iOS app and every backend thread build against these shapes;
// change them only together with docs/backend/contract.md and tell the other side.

export const verdictValidator = v.union(
  v.literal("BUY_NOW"),
  v.literal("WAIT"),
  v.literal("CONSIDER_ALTERNATIVE"),
  v.literal("INVESTIGATE"),
);
export type Verdict = Infer<typeof verdictValidator>;
export const VERDICTS: Verdict[] = ["BUY_NOW", "WAIT", "CONSIDER_ALTERNATIVE", "INVESTIGATE"];

// phone -> backend: only extracted fields, never the screenshot.
export const productExtractValidator = v.object({
  deviceId: v.optional(v.string()),
  retailer: v.optional(v.string()),
  title: v.optional(v.string()),
  currentPrice: v.optional(v.number()),
  originalPrice: v.optional(v.number()),
  url: v.optional(v.string()),
  ocrLines: v.optional(v.array(v.string())),
  capturedAt: v.optional(v.number()),
});
export type ProductExtract = Infer<typeof productExtractValidator>;

// backend -> phone: one verdict, one line, a confidence, and whether the evidence is sample data.
export const analyzeResponseValidator = v.object({
  productId: v.optional(v.string()),
  matchedTitle: v.optional(v.string()),
  verdict: verdictValidator,
  reason: v.string(),
  confidence: v.number(),
  isSampleData: v.boolean(),
  // "pending": a fuller background analysis is running; fetch GET /report?productId= later.
  reportStatus: v.optional(v.union(v.literal("ready"), v.literal("pending"), v.literal("none"))),
});
export type AnalyzeResponse = Infer<typeof analyzeResponseValidator>;

export const observationSourceValidator = v.union(
  v.literal("scan"),
  v.literal("api"),
  v.literal("scrape"),
  v.literal("seed"),
);
export type ObservationSource = Infer<typeof observationSourceValidator>;

const cited = { evidenceIds: v.array(v.string()) };

// The structured analysis report (mirrors AgentOutput in convex/agent/output.ts); each section cites evidence ids.
export const reportValidator = v.object({
  match: v.object({ productId: v.union(v.string(), v.null()), confidence: v.number(), note: v.string() }),
  verdict: verdictValidator,
  confidence: v.number(),
  reason: v.string(),
  reasonEvidenceIds: v.array(v.string()),
  priceAssessment: v.object({ summary: v.string(), ...cited }),
  discount: v.object({
    status: v.union(v.literal("genuine"), v.literal("misleading"), v.literal("no_discount_claimed"), v.literal("unclear")),
    signals: v.array(v.union(v.literal("was_price_rarely_seen"), v.literal("price_raised_before_sale"), v.literal("sale_price_is_normal_price"), v.literal("small_real_savings"))),
    explanation: v.string(),
    ...cited,
  }),
  forecast: v.object({
    low: v.union(v.number(), v.null()),
    high: v.union(v.number(), v.null()),
    byDate: v.union(v.string(), v.null()),
    confidence: v.number(),
    explanation: v.string(),
    ...cited,
  }),
  retailers: v.object({ summary: v.string(), ...cited }),
  competitors: v.array(v.object({ productId: v.string(), title: v.string(), valueReasoning: v.string(), ...cited })),
  recommendation: v.object({ reasoning: v.string(), ...cited }),
});


const specValue = v.union(v.string(), v.number(), v.boolean());
const nullableNumber = v.union(v.number(), v.null());
const nullableString = v.union(v.string(), v.null());

// Deterministic report sections, computed in code from the same evidence the model cites (agent/insights.ts).
export const insightsValidator = v.object({
  forecast: v.object({
    outlook: v.union(v.literal("better_price_likely"), v.literal("better_price_possible"), v.literal("no_better_price_expected"), v.literal("unknown")),
    low: nullableNumber,
    high: nullableNumber,
    byDate: nullableString,
    basedOn: v.union(v.literal("past_event_editions"), v.literal("sale_cycle"), v.literal("none")),
    eventName: nullableString,
    pastEditions: v.number(),
    confidence: v.number(),
    savingsAtLow: nullableNumber,
    savingsAtLowPercent: nullableNumber,
  }),
  retailerPatterns: v.array(v.object({
    retailer: v.string(),
    latestPrice: v.number(),
    latestSeen: v.string(),
    typicalPrice: v.number(),
    lowestPrice: v.number(),
    observationCount: v.number(),
    saleEpisodes: v.number(),
    medianSaleDepthPercent: nullableNumber,
    deepestSalePrice: nullableNumber,
    lastSaleStarted: nullableString,
    advertisedDiscounts: v.number(),
    advertisedWithRarelyChargedWasPrice: v.number(),
    priceRaisedBeforeSale: v.number(),
  })),
  discountAuthenticity: v.object({
    claimedWasPrice: nullableNumber,
    wasPriceChargedSharePercent: nullableNumber,
    claimedDiscountPercent: nullableNumber,
    realDiscountVsTypicalPercent: nullableNumber,
    saleEpisodes12Months: v.number(),
    medianDaysBetweenSales: nullableNumber,
    discountingIsRoutine: v.boolean(),
    pastAdvertisedDiscounts: v.number(),
    pastAdvertisedWithRarelyChargedWasPrice: v.number(),
    preSaleHikes: v.array(v.object({ retailer: v.string(), saleStarted: v.string(), hikePercent: nullableNumber })),
  }),
  competitorComparison: v.array(v.object({
    productId: v.string(),
    title: v.string(),
    brand: v.string(),
    latestPrice: v.number(),
    retailer: nullableString,
    observations90Days: v.number(),
    similarityPercent: v.number(),
    savingsVsCurrent: nullableNumber,
    savingsPercent: nullableNumber,
    matchingSpecsPercent: nullableNumber,
    specs: v.array(v.object({ key: v.string(), thisProduct: v.union(specValue, v.null()), competitor: v.union(specValue, v.null()), same: v.boolean() })),
  })),
});

// Chart-ready price history for GET /report: step series per retailer, sale events, and point sources.
export const chartValidator = v.object({
  kind: v.literal("step"),
  from: nullableString,
  to: nullableString,
  series: v.array(v.object({ retailer: v.string(), points: v.array(v.object({ date: v.string(), price: v.number(), source: v.string() })), lowest: v.number(), latest: v.number() })),
  lowest: v.union(v.null(), v.object({ price: v.number(), date: v.string(), retailer: v.string() })),
  typicalPrice: nullableNumber,
  events: v.array(v.object({ name: v.string(), startsAt: v.string(), endsAt: v.string(), retailer: nullableString })),
  sources: v.record(v.string(), v.number()),
  isSampleData: v.boolean(),
});

// backend -> phone: GET /report?productId= (on demand, not on the live path).
export const reportResponseValidator = v.object({
  product: v.object({ productId: v.id("products"), title: v.string(), brand: v.string(), category: v.string(), provisional: v.boolean(), isSample: v.boolean() }),
  pending: v.boolean(),
  chart: chartValidator,
  analysis: v.union(
    v.null(),
    v.object({
      analysisId: v.id("analyses"),
      tier: v.union(v.literal("live"), v.literal("full")),
      source: v.union(v.literal("model"), v.literal("heuristic")),
      model: v.string(),
      createdAt: v.number(),
      scanPrice: v.union(v.number(), v.null()),
      verdict: verdictValidator,
      confidence: v.number(),
      reason: v.string(),
      report: reportValidator,
      evidence: v.array(v.object({ id: v.string(), tool: v.string(), args: v.any(), result: v.any() })),
      groundingIssues: v.array(v.string()),
      isSampleData: v.boolean(),
      insights: v.union(v.null(), insightsValidator),
    }),
  ),
});
export type ReportResponse = Infer<typeof reportResponseValidator>;

// backend -> phone: one unacknowledged notification from GET /watchlist/notifications (monitoring's inbox).
export const notificationValidator = v.object({
  id: v.id("notificationLog"),
  productId: v.id("products"),
  title: v.string(),
  body: v.string(),
  price: v.number(),
  verdict: verdictValidator,
  trigger: v.union(v.literal("target_hit"), v.literal("new_low"), v.literal("buy_now_flip"), v.literal("sale_start"), v.literal("better_alternative")),
  simulated: v.boolean(),
  channel: v.optional(v.union(v.literal("apns"), v.literal("inbox"))),
  createdAt: v.number(),
});
export type Notification = Infer<typeof notificationValidator>;
