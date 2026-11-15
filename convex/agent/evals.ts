import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction, internalQuery } from "../_generated/server";
import type { Id } from "../_generated/dataModel";
import { verdictValidator, type Verdict } from "../lib/contract";
import type { FunctionReturnType } from "convex/server";
import type { ScanResult } from "./analyze";

type Latest = FunctionReturnType<typeof internal.agent.store.latestAnalyses>;
type Keys = { familyKey: string; variant: Record<string, string> | null; provisional: boolean } | null;
type FullRun = { verdict: Verdict; source: string; latencyMs: number; issues: string[] };

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

type TierResult = { verdict: Verdict; confidence: number; reason: string; source: string; latencyMs: number; groundingIssues: string[] } | null;
type Score = { verdictOk: boolean; confidenceOk: boolean; grounded: boolean; usedModel: boolean } | null;
export type EvalResult = { id: string; matchOk: boolean; matchedFamily: string | null; live: TierResult; liveScore: Score; full: TierResult; fullScore: Score };

// Runs each eval case through the live pass and the full run without recording prices or touching the cache,
// and scores identification, verdict, confidence ceiling, and grounding. Wording is left for a human to judge.
export const run = internalAction({
  args: { cases: v.array(caseValidator), now: v.number(), full: v.optional(v.boolean()) },
  handler: async (ctx, { cases, now, full }): Promise<EvalResult[]> => {
    const results: EvalResult[] = [];
    for (const c of cases) {
      const live: ScanResult = await ctx.runAction(internal.agent.analyze.analyzeScan, { ...c.extract, now, evaluation: true });
      const productId = live.productId as Id<"products"> | undefined;
      const keys: Keys = productId ? await ctx.runQuery(internal.agent.evals.productKeys, { productId }) : null;
      const matched: Keys = keys && !keys.provisional ? keys : null;
      const matchOk: boolean =
        c.expectFamily === null ? matched === null : matched?.familyKey === c.expectFamily && Object.entries(c.expectVariant ?? {}).every(([k, val]) => matched?.variant?.[k] === val);
      const latest: Latest | null = productId ? await ctx.runQuery(internal.agent.store.latestAnalyses, { productId }) : null;
      const liveTier: TierResult = latest?.live
        ? { verdict: latest.live.verdict, confidence: latest.live.confidence, reason: latest.live.reason, source: latest.live.source, latencyMs: live.latencyMs, groundingIssues: latest.live.groundingIssues }
        : { verdict: live.verdict, confidence: live.confidence, reason: live.reason, source: live.path, latencyMs: live.latencyMs, groundingIssues: [] };
      let fullTier: TierResult = null;
      if (full && matched && productId) {
        const r: FullRun = await ctx.runAction(internal.agent.analyze.runFullAnalysis, {
          productId,
          now,
          scan: { title: c.extract.title ?? null, retailer: c.extract.retailer ?? "unknown", currentPrice: c.extract.currentPrice ?? null, originalPrice: c.extract.originalPrice ?? null },
        });
        const stored: Latest = await ctx.runQuery(internal.agent.store.latestAnalyses, { productId });
        fullTier = { verdict: r.verdict, confidence: stored.full!.confidence, reason: stored.full!.reason, source: r.source, latencyMs: r.latencyMs, groundingIssues: r.issues };
      }
      const score = (t: TierResult): Score =>
        t && {
          verdictOk: c.acceptable.includes(t.verdict),
          confidenceOk: c.maxConfidence === undefined || t.confidence <= c.maxConfidence,
          grounded: t.source === "heuristic" ? !t.groundingIssues.some((i) => i.startsWith("heuristic:")) : t.groundingIssues.length === 0,
          usedModel: t.source === "model" || t.source === "cache" || t.source === "live",
        };
      results.push({ id: c.id, matchOk, matchedFamily: matched?.familyKey ?? null, live: liveTier, liveScore: score(liveTier), full: fullTier, fullScore: score(fullTier) });
    }
    return results;
  },
});
