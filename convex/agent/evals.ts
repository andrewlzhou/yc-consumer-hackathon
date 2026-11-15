import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction, internalQuery } from "../_generated/server";
import type { Id } from "../_generated/dataModel";
import { verdictValidator, type Verdict } from "../lib/contract";
import type { FunctionReturnType } from "convex/server";
import type { ScanResult } from "./analyze";

type Stored = FunctionReturnType<typeof internal.agent.store.analysisById>;
type Keys = { familyKey: string; variant: Record<string, string> | null; provisional: boolean } | null;
type FullRun = { analysisId: Id<"analyses">; verdict: Verdict; source: string; latencyMs: number; issues: string[] };

export const caseValidator = v.object({
  id: v.string(),
  extract: v.object({ title: v.optional(v.string()), retailer: v.optional(v.string()), currentPrice: v.optional(v.number()), originalPrice: v.optional(v.number()) }),
  expectFamily: v.union(v.string(), v.null()),
  expectVariant: v.optional(v.record(v.string(), v.string())),
  acceptable: v.array(verdictValidator),
  maxConfidence: v.optional(v.number()),
});

export const productKeys = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, { productId }) => {
    const p = await ctx.db.get(productId);
    return p && { familyKey: p.familyKey, variant: p.variant ?? null, provisional: p.provisional };
  },
});

type TierResult = { verdict: Verdict; confidence: number; reason: string; source: string; latencyMs: number; groundingIssues: string[]; usage: { inputTokens: number; outputTokens: number } | null } | null;
type Score = { verdictOk: boolean; confidenceOk: boolean; grounded: boolean; usedModel: boolean } | null;
export type EvalResult = { id: string; timings: Record<string, number>; matchOk: boolean; matchedFamily: string | null; live: TierResult; liveScore: Score; full: TierResult; fullScore: Score };

// Runs each eval case through the live pass and the full run without recording prices or touching the cache,
// and scores identification, verdict, confidence ceiling, and grounding. Wording is left for a human to judge.
export const run = internalAction({
  args: { cases: v.array(caseValidator), now: v.number(), full: v.optional(v.boolean()) },
  handler: async (ctx, { cases, now, full }): Promise<EvalResult[]> => {
    const results: EvalResult[] = [];
    for (const c of cases) {
      const live: ScanResult = await ctx.runAction(internal.agent.analyze.analyzeScan, { ...c.extract, now, evaluation: true });
      const productId = live.response.productId as Id<"products"> | undefined;
      const keys: Keys = productId ? await ctx.runQuery(internal.agent.evals.productKeys, { productId }) : null;
      const matched: Keys = keys && !keys.provisional ? keys : null;
      const matchOk: boolean =
        c.expectFamily === null ? matched === null : matched?.familyKey === c.expectFamily && Object.entries(c.expectVariant ?? {}).every(([k, val]) => matched?.variant?.[k] === val);
      // Read back the exact rows this run wrote; other scans on a shared deployment may have newer ones.
      const stored: Stored = live.analysisId ? await ctx.runQuery(internal.agent.store.analysisById, { analysisId: live.analysisId }) : null;
      const liveTier: TierResult = stored
        ? { ...stored, latencyMs: live.latencyMs }
        : { verdict: live.response.verdict, confidence: live.response.confidence, reason: live.response.reason, source: live.path, latencyMs: live.latencyMs, groundingIssues: [], usage: null };
      let fullTier: TierResult = null;
      if (full && matched && productId) {
        const r: FullRun = await ctx.runAction(internal.agent.analyze.runFullAnalysis, {
          productId,
          now,
          scan: { title: c.extract.title ?? null, retailer: c.extract.retailer ?? "unknown", currentPrice: c.extract.currentPrice ?? null, originalPrice: c.extract.originalPrice ?? null },
        });
        const full: Stored = await ctx.runQuery(internal.agent.store.analysisById, { analysisId: r.analysisId });
        fullTier = { ...full!, latencyMs: r.latencyMs, groundingIssues: r.issues };
      }
      const score = (t: TierResult): Score =>
        t && {
          verdictOk: c.acceptable.includes(t.verdict),
          confidenceOk: c.maxConfidence === undefined || t.confidence <= c.maxConfidence,
          grounded: t.source === "heuristic" ? !t.groundingIssues.some((i) => i.startsWith("heuristic:")) : t.groundingIssues.length === 0,
          usedModel: t.source === "model" || t.source === "cache" || t.source === "live",
        };
      results.push({ id: c.id, timings: live.timings, matchOk, matchedFamily: matched?.familyKey ?? null, live: liveTier, liveScore: score(liveTier), full: fullTier, fullScore: score(fullTier) });
    }
    return results;
  },
});
