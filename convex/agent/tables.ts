// Shopping-agent tables. schema.ts spreads this object so this thread's tables stay in one block.
import { defineTable } from "convex/server";
import { v } from "convex/values";
import { reportValidator, verdictValidator } from "../lib/contract";

export { reportValidator };

// Tool results are stored as JSON text so arbitrary keys and shapes survive Convex's value rules.
export const evidenceValidator = v.object({ id: v.string(), tool: v.string(), args: v.string(), result: v.string() });

export const tierValidator = v.union(v.literal("live"), v.literal("full"));
export const analysisSourceValidator = v.union(v.literal("model"), v.literal("heuristic"));

export const agentTables = {
  // One stored analysis per run. The newest full-tier row is the product's detailed report.
  analyses: defineTable({
    productId: v.id("products"),
    tier: tierValidator,
    source: analysisSourceValidator,
    model: v.string(),
    createdAt: v.number(),
    scanPrice: v.optional(v.number()),
    verdict: verdictValidator,
    confidence: v.number(),
    reason: v.string(),
    report: reportValidator,
    evidence: v.array(evidenceValidator),
    groundingIssues: v.array(v.string()),
    latencyMs: v.number(),
    usage: v.object({ inputTokens: v.number(), outputTokens: v.number() }),
    isSampleData: v.boolean(),
  }).index("by_productId_and_tier_and_createdAt", ["productId", "tier", "createdAt"]),

  // Background full runs, so repeated scans of one product queue a single run.
  analysisJobs: defineTable({
    productId: v.id("products"),
    status: v.union(v.literal("queued"), v.literal("running"), v.literal("done"), v.literal("failed")),
    requestedAt: v.number(),
    finishedAt: v.optional(v.number()),
    error: v.optional(v.string()),
  }).index("by_productId_and_requestedAt", ["productId", "requestedAt"]),

  // Product links the phone sent (share menu, Safari), resolved in the background to a catalog product.
  resolvedUrls: defineTable({
    url: v.string(),
    status: v.union(v.literal("pending"), v.literal("resolved"), v.literal("failed")),
    productId: v.optional(v.id("products")),
    resolvedAt: v.number(),
    error: v.optional(v.string()),
  }).index("by_url", ["url"]),

  // One row per /analyze call with the path taken and measured latency.
  agentScans: defineTable({
    productId: v.optional(v.id("products")),
    title: v.optional(v.string()),
    retailerSlug: v.string(),
    price: v.optional(v.number()),
    verdict: verdictValidator,
    path: v.union(v.literal("cache"), v.literal("live"), v.literal("heuristic"), v.literal("unknown")),
    latencyMs: v.number(),
    at: v.number(),
  }).index("by_at", ["at"]),
};
