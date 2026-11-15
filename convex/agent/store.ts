import { v } from "convex/values";
import { internalMutation, internalQuery } from "../_generated/server";
import { reportResponseValidator, verdictValidator } from "../lib/contract";
import { analysisSourceValidator, evidenceValidator, reportValidator, tierValidator } from "./tables";

const JOB_TIMEOUT_MS = 10 * 60_000;

export const latestAnalyses = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, { productId }) => {
    const newest = (tier: "live" | "full") =>
      ctx.db.query("analyses").withIndex("by_productId_and_tier_and_createdAt", (q) => q.eq("productId", productId).eq("tier", tier)).order("desc").first();
    const [live, full] = await Promise.all([newest("live"), newest("full")]);
    return { live, full };
  },
});

export const saveAnalysis = internalMutation({
  args: {
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
  },
  handler: async (ctx, args) => ctx.db.insert("analyses", args),
});

// Returns a new job id, or null when a queued or running job for this product started recently.
export const claimJob = internalMutation({
  args: { productId: v.id("products"), now: v.number() },
  handler: async (ctx, { productId, now }) => {
    const last = await ctx.db.query("analysisJobs").withIndex("by_productId_and_requestedAt", (q) => q.eq("productId", productId)).order("desc").first();
    if (last && (last.status === "queued" || last.status === "running") && now - last.requestedAt < JOB_TIMEOUT_MS) return null;
    return ctx.db.insert("analysisJobs", { productId, status: "queued", requestedAt: now });
  },
});

export const finishJob = internalMutation({
  args: { jobId: v.id("analysisJobs"), status: v.union(v.literal("running"), v.literal("done"), v.literal("failed")), error: v.optional(v.string()) },
  handler: async (ctx, { jobId, status, error }) => {
    await ctx.db.patch(jobId, status === "running" ? { status } : { status, error, finishedAt: Date.now() });
    return null;
  },
});

export const logScan = internalMutation({
  args: {
    productId: v.optional(v.id("products")),
    title: v.optional(v.string()),
    retailerSlug: v.string(),
    price: v.optional(v.number()),
    verdict: verdictValidator,
    path: v.union(v.literal("cache"), v.literal("live"), v.literal("heuristic"), v.literal("unknown")),
    latencyMs: v.number(),
    at: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("agentScans", args);
    return null;
  },
});

// The detailed report for a product: newest full analysis (or live if no full run yet) and whether a run is pending.
export const report = internalQuery({
  args: { productId: v.id("products") },
  returns: v.union(v.null(), reportResponseValidator),
  handler: async (ctx, { productId }) => {
    const product = await ctx.db.get(productId);
    if (!product) return null;
    const newest = (tier: "live" | "full") =>
      ctx.db.query("analyses").withIndex("by_productId_and_tier_and_createdAt", (q) => q.eq("productId", productId).eq("tier", tier)).order("desc").first();
    const [full, live, job] = await Promise.all([
      newest("full"),
      newest("live"),
      ctx.db.query("analysisJobs").withIndex("by_productId_and_requestedAt", (q) => q.eq("productId", productId)).order("desc").first(),
    ]);
    const analysis = full ?? live;
    return {
      product: { productId, title: product.title, brand: product.brand, category: product.category, provisional: product.provisional, isSample: product.isSample },
      pending: !!job && (job.status === "queued" || job.status === "running"),
      analysis: analysis && {
        analysisId: analysis._id,
        tier: analysis.tier,
        source: analysis.source,
        model: analysis.model,
        createdAt: analysis.createdAt,
        scanPrice: analysis.scanPrice ?? null,
        verdict: analysis.verdict,
        confidence: analysis.confidence,
        reason: analysis.reason,
        report: analysis.report,
        evidence: analysis.evidence.map((e) => ({ id: e.id, tool: e.tool, args: JSON.parse(e.args) as unknown, result: JSON.parse(e.result) as unknown })),
        groundingIssues: analysis.groundingIssues,
        isSampleData: analysis.isSampleData,
      },
    };
  },
});
