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
