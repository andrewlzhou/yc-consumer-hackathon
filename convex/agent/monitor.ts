import { internal } from "../_generated/api";
import type { ActionCtx } from "../_generated/server";
import type { Id } from "../_generated/dataModel";
import type { Verdict } from "../lib/contract";

const HOUR = 3_600_000;
const STALE_MS = 12 * HOUR;
const PRICE_TOLERANCE = 0.02;

export type MonitoringAnalysis = {
  verdict: Verdict;
  confidence: number;
  reason: string;
  isSampleData: boolean;
  alternative?: { title: string; price: number; savingsPct: number };
};

// isSampleData is true when any evidence behind the analysis is seeded; monitoring must not push on it.
// Monitoring's view of the agent: the newest stored analysis for a product, plus a background full run queued
// when that analysis is missing, older than 12 hours, or was made at a price more than 2% away from today's.
export async function analysisForMonitoring(ctx: ActionCtx, productId: Id<"products">, currentPrice: number, retailer: string, now: number): Promise<MonitoringAnalysis | null> {
  const { live, full } = await ctx.runQuery(internal.agent.store.latestAnalyses, { productId });
  const newest = [full, live].filter((a) => a !== null).sort((a, b) => b!.createdAt - a!.createdAt)[0] ?? null;
  const priceMoved = (a: NonNullable<typeof newest>) => a.scanPrice !== undefined && Math.abs(a.scanPrice - currentPrice) / currentPrice > PRICE_TOLERANCE;
  if (!full || now - full.createdAt > STALE_MS || priceMoved(full)) {
    const jobId = await ctx.runMutation(internal.agent.store.claimJob, { productId, now: Date.now() });
    if (jobId)
      await ctx.scheduler.runAfter(0, internal.agent.analyze.runFullAnalysis, { productId, jobId, now, scan: { title: null, retailer, currentPrice, originalPrice: null } });
  }
  if (!newest || priceMoved(newest)) return null;
  const result: MonitoringAnalysis = { verdict: newest.verdict, confidence: newest.confidence, reason: newest.reason, isSampleData: newest.isSampleData };
  const pick = newest.report.competitors[0];
  if (newest.verdict === "CONSIDER_ALTERNATIVE" && pick) {
    const offered = newest.evidence
      .filter((e) => e.tool === "find_competitors")
      .flatMap((e) => JSON.parse(e.result) as { productId: string; last90Days: { latestPrice: number | null } }[])
      .find((c) => c.productId === pick.productId)?.last90Days.latestPrice;
    if (offered && offered < currentPrice)
      result.alternative = { title: pick.title, price: offered, savingsPct: Math.round(((currentPrice - offered) / currentPrice) * 1000) / 10 };
  }
  return result;
}
