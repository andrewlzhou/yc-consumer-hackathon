import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalMutation, internalQuery } from "../_generated/server";
import { loadWindow } from "../data/prices";
import { chartData } from "./chart";
import { reportResponseValidator, verdictValidator, type ReportResponse } from "../lib/contract";
import type { Insights } from "./insights";
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

export const analysisById = internalQuery({
  args: { analysisId: v.id("analyses") },
  handler: async (ctx, { analysisId }) => {
    const a = await ctx.db.get(analysisId);
    return a && { verdict: a.verdict, confidence: a.confidence, reason: a.reason, source: a.source, groundingIssues: a.groundingIssues, usage: a.usage };
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

const DAY = 86_400_000;

// The detailed report for a product: the newest analysis (the full one on a tie), whether a full run is pending,
// the deterministic sections, and a chart of the last year of prices. now comes from the caller: queries have no clock.
export const report = internalQuery({
  args: { productId: v.id("products"), now: v.number() },
  returns: v.union(v.null(), reportResponseValidator),
  handler: async (ctx, { productId, now }): Promise<ReportResponse | null> => {
    const product = await ctx.db.get(productId);
    if (!product) return null;
    const newest = (tier: "live" | "full") =>
      ctx.db.query("analyses").withIndex("by_productId_and_tier_and_createdAt", (q) => q.eq("productId", productId).eq("tier", tier)).order("desc").first();
    const [full, live, job, history, events] = await Promise.all([
      newest("full"),
      newest("live"),
      ctx.db.query("analysisJobs").withIndex("by_productId_and_requestedAt", (q) => q.eq("productId", productId)).order("desc").first(),
      loadWindow(ctx, productId, undefined, now - 365 * DAY, now),
      ctx.runQuery(internal.data.calendar.getSaleCalendar, { from: now - 365 * DAY, to: now + 45 * DAY }),
    ]);
    const analysis = full && (!live || full.createdAt >= live.createdAt) ? full : (live ?? full);
    const insights = analysis?.evidence.find((e) => e.tool === "insights");
    return {
      product: { productId, title: product.title, brand: product.brand, category: product.category, provisional: product.provisional, isSample: product.isSample },
      pending: !!job && (job.status === "queued" || job.status === "running"),
      chart: chartData(history.rows, events),
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
        insights: insights ? (JSON.parse(insights.result) as Insights) : null,
      },
    };
  },
});

// Operator cleanup after latency probes or manual tests on a shared deployment: deletes scan-source observations
// and stored analyses created at or after `since` (epoch ms). Run with npx convex run; never called by the app.
export const deleteTestArtifacts = internalMutation({
  args: { since: v.number() },
  handler: async (ctx, { since }) => {
    let observations = 0;
    let analyses = 0;
    for await (const row of ctx.db.query("priceObservations").withIndex("by_creation_time", (q) => q.gte("_creationTime", since))) {
      if (row.source !== "scan") continue;
      await ctx.db.delete(row._id);
      observations++;
    }
    for await (const row of ctx.db.query("analyses").withIndex("by_creation_time", (q) => q.gte("_creationTime", since))) {
      await ctx.db.delete(row._id);
      analyses++;
    }
    return { observations, analyses };
  },
});
