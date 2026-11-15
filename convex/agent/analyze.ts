import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction, type ActionCtx } from "../_generated/server";
import type { Id } from "../_generated/dataModel";
import { analyzeResponseValidator, productExtractValidator, type AnalyzeResponse, type Verdict } from "../lib/contract";
import { KNOWN_RETAILERS, normalizeRetailer } from "../data/retailers";
import { rateLimiter } from "./limits";
import { checkCard, checkGrounding, EvidenceLedger, type Evidence } from "./evidence";
import { fakeProvider } from "./fake";
import { heuristicAnalysis, isThin } from "./heuristic";
import { decideMatch, hybridViable, type MatchCandidate } from "./identify";
import type { LlmProvider } from "./llm";
import { reportSpec, runAgent, type OutputSpec } from "./loop";
import { openAiProvider } from "./openai";
import { CARD_SCHEMA, parseCard, type AgentCard, type AgentOutput } from "./output";
import { dataPort, type DataPort } from "./port";
import { keyFacts } from "./facts";
import { systemPrompt } from "./prompt";
import { buildTools, COMPETITOR_TOOLS } from "./tools";

const HOUR = 3_600_000;
const FULL_CACHE_MS = 12 * HOUR;
const LIVE_CACHE_MS = HOUR / 2;
const PRICE_TOLERANCE = 0.02;
const LIVE_DEADLINE_MS = 4000;
export const SAMPLE_NOTE = " (sample data)";

type Reasoning = "none" | "minimal" | "low" | "medium" | "high";

// Fake provider when forced (tests, offline eval) or when no OpenAI key is configured.
export function agentConfig() {
  const useFake = process.env.AGENT_PROVIDER === "fake" || !process.env.OPENAI_API_KEY;
  const provider: LlmProvider = useFake ? fakeProvider() : openAiProvider(process.env.OPENAI_API_KEY!);
  return {
    provider,
    fast: { model: useFake ? "fake" : (process.env.AGENT_FAST_MODEL ?? "gpt-5.4-mini"), reasoning: (process.env.AGENT_FAST_REASONING ?? "none") as Reasoning },
    full: { model: useFake ? "fake" : (process.env.AGENT_FULL_MODEL ?? "gpt-6.1-sol"), reasoning: (process.env.AGENT_FULL_REASONING ?? "low") as Reasoning },
  };
}

export type Scan = { title: string | null; retailer: string; currentPrice: number | null; originalPrice: number | null };
const scanValidator = v.object({ title: v.union(v.string(), v.null()), retailer: v.string(), currentPrice: v.union(v.number(), v.null()), originalPrice: v.union(v.number(), v.null()) });
const positive = (n: number | undefined) => (typeof n === "number" && Number.isFinite(n) && n > 0 ? n : null);
const orUndefined = <T>(x: T | null) => x ?? undefined;

// Picks among close catalog candidates, or none. The fake (and any model failure) takes the top candidate.
async function pickCandidate(provider: LlmProvider, model: string, title: string, candidates: MatchCandidate[]): Promise<MatchCandidate | null> {
  if (provider.name === "fake") return candidates[0] ?? null;
  try {
    const result = await provider.turn({
      model,
      reasoning: "none",
      system: "Match a scanned product title to one catalog product. Storage, size, and pack count must match; color does not matter. Answer null if none is the same product.",
      items: [{ kind: "user", text: JSON.stringify({ scannedTitle: title, candidates: candidates.map((c) => ({ productId: c.product._id, title: c.product.title, brand: c.product.brand, variant: c.product.variant ?? null })) }) }],
      tools: [],
      output: { name: "match", schema: { type: "object", properties: { productId: { type: ["string", "null"] } }, required: ["productId"], additionalProperties: false } },
      maxOutputTokens: 60,
      timeoutMs: 2500,
    });
    if (result.kind !== "final") return candidates[0];
    const id = (JSON.parse(result.text) as { productId: string | null }).productId;
    return candidates.find((c) => c.product._id === id) ?? null;
  } catch {
    return candidates[0];
  }
}

function scanPrompt(scan: Scan, productId: string, productTitle: string): string {
  return `<scan>${JSON.stringify({ productId, retailer: scan.retailer, title: scan.title, currentPrice: scan.currentPrice, originalPrice: scan.originalPrice })}</scan>
The shopper is looking at "${scan.title ?? productTitle}" at ${scan.retailer}${scan.currentPrice !== null ? ` for $${scan.currentPrice}` : ""}${scan.originalPrice !== null ? ` (shown as "was $${scan.originalPrice}")` : ""}. It matched catalog product ${productId}: "${productTitle}".`;
}


// The evidence every verdict rests on. Reused from the ledger when the model already fetched it.
async function standardEvidence(data: DataPort, ledger: EvidenceLedger, productId: string, scan: Scan) {
  const find = (tool: string) =>
    [...ledger.items].reverse().find((e) => {
      const args = e.args as { productId?: string; retailer?: unknown; days?: unknown };
      return e.tool === tool && args.productId === productId && (tool !== "get_price_stats" || (args.retailer === null && args.days === 365));
    });
  const statsArgs = { productId, retailer: null, days: 365, currentPrice: scan.currentPrice, originalPrice: scan.originalPrice };
  const recentArgs = { productId, retailer: null, days: 90, currentPrice: scan.currentPrice, originalPrice: null };
  const [stats, recent, promo, competitors] = await Promise.all([
    find("get_price_stats") ?? data.stats(productId, { days: 365, currentPrice: orUndefined(scan.currentPrice), originalPrice: orUndefined(scan.originalPrice) }),
    data.stats(productId, { days: 90, currentPrice: orUndefined(scan.currentPrice) }),
    find("get_promo_patterns") ?? data.promo(productId),
    find("find_competitors") ?? data.comparables(productId),
  ]);
  const asEvidence = (tool: string, args: object, value: unknown) => (value && typeof value === "object" && "id" in value && "tool" in value ? (value as Evidence) : ledger.add(tool, args, value));
  const ev = {
    stats: asEvidence("get_price_stats", statsArgs, stats),
    promo: asEvidence("get_promo_patterns", { productId, retailer: null }, promo),
    competitors: asEvidence("find_competitors", { productId }, competitors),
  };
  const recentStats = ledger.add("get_price_stats", recentArgs, recent);
  const facts = ledger.add("key_facts", { productId, retailer: scan.retailer }, keyFacts(scan.retailer, ev.stats, recentStats, ev.promo, ev.competitors));
  return { ...ev, facts };
}

// Prompt rendering of evidence. Long promo episode lists are trimmed for the prompt; the ledger keeps them whole.
function evidenceBlock(e: Evidence): string {
  if (e.tool !== "get_promo_patterns") return `<evidence id="${e.id}" tool="${e.tool}">${JSON.stringify(e.result)}</evidence>`;
  const { episodes, ...rest } = e.result as { episodes?: unknown[] };
  return `<evidence id="${e.id}" tool="${e.tool}">${JSON.stringify({ ...rest, recentEpisodes: (episodes ?? []).slice(-6) })}</evidence>`;
}

const cardSpec: OutputSpec<AgentCard> = { name: "purchase_card", schema: CARD_SCHEMA, parse: parseCard, check: checkCard };

// The live record's report: the model's card on top of the deterministic analyst's factual sections. The full run
// replaces it with a report the larger model writes itself.
function withReport(card: AgentCard, productId: string, scan: Scan, ev: Awaited<ReturnType<typeof standardEvidence>>): AgentOutput {
  const facts = heuristicAnalysis({ productId, retailer: scan.retailer, stats: ev.stats, promo: ev.promo, competitors: ev.competitors });
  return { ...facts, ...card, recommendation: { reasoning: card.reason, evidenceIds: card.reasonEvidenceIds } };
}

// Guardrails after the model: invalid or ungrounded answers and confident verdicts on thin data fall back to the
// deterministic analyst, whose text only copies numbers from evidence.
function finalize(productId: string, scan: Scan, ledger: EvidenceLedger, model: { output: AgentOutput | null; issues: string[] }, ev: Awaited<ReturnType<typeof standardEvidence>>) {
  const issues = [...model.issues];
  let output = model.output;
  let source: "model" | "heuristic" = "model";
  if (output && isThin(ev.stats.result) && output.verdict !== "INVESTIGATE") issues.push(`guardrail: thin history, model said ${output.verdict}`);
  if (!output || issues.length > 0) {
    output = heuristicAnalysis({ productId, retailer: scan.retailer, stats: ev.stats, promo: ev.promo, competitors: ev.competitors });
    source = "heuristic";
    issues.push(...checkGrounding(output, ledger, COMPETITOR_TOOLS).map((i) => `heuristic: ${i}`));
  }
  return { output: { ...output, match: { ...output.match, productId } }, source, issues };
}

type Run = { output: AgentOutput; source: "model" | "heuristic"; issues: string[] };

async function save(ctx: ActionCtx, productId: Id<"products">, tier: "live" | "full", model: string, scan: Scan, run: Run, usage: { inputTokens: number; outputTokens: number }, ledger: EvidenceLedger, latencyMs: number, isSampleData: boolean, now: number) {
  const reason = isSampleData && !run.output.reason.endsWith(SAMPLE_NOTE) ? run.output.reason + SAMPLE_NOTE : run.output.reason;
  const analysisId: Id<"analyses"> = await ctx.runMutation(internal.agent.store.saveAnalysis, {
    productId,
    tier,
    source: run.source,
    model: run.source === "heuristic" ? `heuristic (after ${model})` : model,
    createdAt: now,
    scanPrice: orUndefined(scan.currentPrice),
    verdict: run.output.verdict,
    confidence: run.output.confidence,
    reason,
    report: { ...run.output, reason },
    evidence: ledger.items.map((e) => ({ id: e.id, tool: e.tool, args: JSON.stringify(e.args), result: JSON.stringify(e.result) })),
    groundingIssues: run.issues,
    latencyMs,
    usage,
    isSampleData,
  });
  return { analysisId, reason };
}

async function queueFullRun(ctx: ActionCtx, productId: Id<"products">, scan: Scan, now: number) {
  const jobId = await ctx.runMutation(internal.agent.store.claimJob, { productId, now: Date.now() });
  if (jobId) await ctx.scheduler.runAfter(0, internal.agent.analyze.runFullAnalysis, { productId, jobId, scan, now });
  return jobId !== null;
}

const pathValidator = v.union(v.literal("cache"), v.literal("live"), v.literal("heuristic"), v.literal("unknown"));
export const scanResultValidator = v.object({ response: analyzeResponseValidator, path: pathValidator, latencyMs: v.number(), timings: v.record(v.string(), v.number()), analysisId: v.optional(v.id("analyses")) });
export type ScanResult = { response: AnalyzeResponse; path: "cache" | "live" | "heuristic" | "unknown"; latencyMs: number; timings: Record<string, number>; analysisId?: Id<"analyses"> };
type Card = AnalyzeResponse & { path: ScanResult["path"]; analysisId?: Id<"analyses"> };

// The live path: identify, record the price, then return a fresh stored analysis or run one fast model pass.
// now is overridable so tests and evals are deterministic against the seed's clock.
export const analyzeScan = internalAction({
  args: { ...productExtractValidator.fields, now: v.optional(v.number()), evaluation: v.optional(v.boolean()) },
  returns: scanResultValidator,
  handler: async (ctx, args): Promise<ScanResult> => {
    // An evaluation run neither records prices, creates products, uses the cache, nor queues background runs.
    const evaluation = args.evaluation === true;
    const started = Date.now();
    const now = args.now ?? started;
    const config = agentConfig();
    const data = dataPort(ctx, now);
    const title = args.title?.trim() || args.ocrLines?.join(" ").trim() || null;
    const scan: Scan = { title, retailer: normalizeRetailer(args.retailer) ?? "unknown", currentPrice: positive(args.currentPrice), originalPrice: positive(args.originalPrice) };
    const ledger = new EvidenceLedger();
    const timings: Record<string, number> = {};
    let mark = started;
    const lap = (name: string) => {
      const t = Date.now();
      timings[name] = t - mark;
      mark = t;
    };
    const finish = async ({ path, analysisId, ...response }: Card): Promise<ScanResult> => {
      const latencyMs = Date.now() - started;
      await ctx.runMutation(internal.agent.store.logScan, { productId: response.productId as Id<"products"> | undefined, title: orUndefined(title), retailerSlug: scan.retailer, price: orUndefined(scan.currentPrice), verdict: response.verdict, path, latencyMs, at: started });
      return { response, path, latencyMs, timings, analysisId };
    };

    let match: MatchCandidate | null = null;
    if (title) {
      const decision = decideMatch(await data.matchProduct(title));
      if (decision.kind === "match") match = decision.candidate;
      else {
        const hybrid = await data.hybridMatch(title);
        const viable = hybrid.mode === "hybrid" ? hybridViable(hybrid.candidates) : decision.kind === "ambiguous" ? decision.candidates : [];
        if (viable.length) match = await pickCandidate(config.provider, config.fast.model, title, viable);
      }
    }
    lap("identify");

    if (!match) {
      if (!title) return finish({ verdict: "INVESTIGATE", reason: "We couldn't read a product name from the screen.", confidence: 0.1, isSampleData: false, reportStatus: "none", path: "unknown" });
      if (evaluation) return finish({ verdict: "INVESTIGATE", reason: "We don't have price history for this product yet, so we can't judge this price.", confidence: 0.2, isSampleData: false, reportStatus: "none", path: "unknown" });
      const allowed = !args.deviceId || (await rateLimiter.limit(ctx, "provisionalPerDevice", { key: args.deviceId })).ok;
      if (!allowed) return finish({ verdict: "INVESTIGATE", reason: "We don't have price history for this product yet, so we can't judge this price.", confidence: 0.2, isSampleData: false, reportStatus: "none", path: "unknown" });
      const productId = await ctx.runMutation(internal.data.catalog.createProvisionalProduct, { title });
      await recordPrice(ctx, productId, scan, args.url, now, args.capturedAt);
      const queued = await queueFullRun(ctx, productId, scan, now);
      return finish({ productId, verdict: "INVESTIGATE", reason: "We don't have price history for this product yet, so we can't judge this price. We've started looking it up.", confidence: 0.2, isSampleData: false, reportStatus: queued ? "pending" : "none", path: "unknown" });
    }

    const productId = match.product._id;
    const [{ live, full }] = await Promise.all([ctx.runQuery(internal.agent.store.latestAnalyses, { productId }), evaluation ? null : recordPrice(ctx, productId, scan, args.url, now, args.capturedAt)]);
    const fresh = (a: typeof live, maxAge: number) =>
      !!a && Math.abs(now - a.createdAt) < maxAge && (scan.currentPrice === null || a.scanPrice === undefined || Math.abs(a.scanPrice - scan.currentPrice) / scan.currentPrice <= PRICE_TOLERANCE);
    lap("cacheAndRecord");
    const fullFresh = fresh(full, FULL_CACHE_MS);
    const cached = evaluation ? null : fullFresh ? full : fresh(live, LIVE_CACHE_MS) ? live : null;
    if (cached) {
      const pending = cached.tier === "live" && (await queueFullRun(ctx, productId, scan, now));
      return finish({ productId, matchedTitle: match.product.title, verdict: cached.verdict, reason: cached.reason, confidence: cached.confidence, isSampleData: cached.isSampleData, reportStatus: cached.tier === "full" ? "ready" : pending ? "pending" : "ready", path: "cache" });
    }

    ledger.add("scan", { retailer: scan.retailer }, { title: scan.title, retailer: scan.retailer, currentPrice: scan.currentPrice, claimedOriginalPrice: scan.originalPrice });
    const ev = await standardEvidence(data, ledger, productId, scan);
    lap("evidence");
    const prompt = [scanPrompt(scan, productId, match.product.title), "This is the fast pass for the phone card: all evidence is below and there are no tools. Answer with verdict, confidence, reason and the evidence ids behind the reason.", ...ledger.items.map(evidenceBlock)].join("\n");
    const run = await runAgent({ provider: config.provider, model: config.fast.model, reasoning: config.fast.reasoning, system: systemPrompt(), prompt, tools: [], output: cardSpec, ledger, maxRepairs: 1, maxOutputTokens: 300, deadlineMs: LIVE_DEADLINE_MS });
    lap("model");
    const final = finalize(productId, scan, ledger, run.ok ? { output: withReport(run.output, productId, scan, ev), issues: run.groundingIssues } : { output: null, issues: [`model failed: ${run.error}`] }, ev);
    const isSampleData = data.sampleDataSeen() || match.product.isSample;
    const { analysisId, reason } = await save(ctx, productId, "live", config.fast.model, scan, final, run.usage, ledger, Date.now() - started, isSampleData, now);
    const pending = !evaluation && !fullFresh && (await queueFullRun(ctx, productId, scan, now));
    return finish({ productId, matchedTitle: match.product.title, verdict: final.output.verdict, reason, confidence: final.output.confidence, isSampleData, reportStatus: pending ? "pending" : "ready", path: final.source === "model" ? "live" : "heuristic", analysisId });
  },
});

// Every scan is a real observation, recorded through the data thread's validator (bad points are dropped there).
async function recordPrice(ctx: ActionCtx, productId: Id<"products">, scan: Scan, url: string | undefined, now: number, capturedAt: number | undefined) {
  if (scan.currentPrice === null || !KNOWN_RETAILERS.some((r) => r.slug === scan.retailer)) return null;
  const observedAt = capturedAt && Math.abs(capturedAt - now) < 86_400_000 ? Math.min(capturedAt, now) : now;
  return ctx.runMutation(internal.data.prices.recordObservation, { productId, retailer: scan.retailer, price: scan.currentPrice, originalPrice: orUndefined(scan.originalPrice), observedAt, source: "scan", url });
}

// The background path: the full tool-use loop with the larger model, stored as the product's detailed report.
export const runFullAnalysis = internalAction({
  args: { productId: v.id("products"), jobId: v.optional(v.id("analysisJobs")), scan: scanValidator, now: v.optional(v.number()) },
  handler: async (ctx, { productId, jobId, scan, now: nowArg }): Promise<{ analysisId: Id<"analyses">; verdict: Verdict; source: "model" | "heuristic"; latencyMs: number; issues: string[]; turns: number }> => {
    const started = Date.now();
    const now = nowArg ?? started;
    if (jobId) await ctx.runMutation(internal.agent.store.finishJob, { jobId, status: "running" });
    try {
      const config = agentConfig();
      const data = dataPort(ctx, now);
      const product = await data.product(productId);
      if (!product) throw new Error("product not found");
      const ledger = new EvidenceLedger();
      ledger.add("scan", { retailer: scan.retailer }, { title: scan.title, retailer: scan.retailer, currentPrice: scan.currentPrice, claimedOriginalPrice: scan.originalPrice });
      ledger.add("get_product", { productId }, { productId, title: product.title, brand: product.brand, category: product.category, variant: product.variant ?? null, specs: product.specs, msrp: product.msrp ?? null, provisional: product.provisional, isSample: product.isSample });
      const ev = await standardEvidence(data, ledger, productId, scan);
      const prompt = [
        scanPrompt(scan, productId, product.title),
        product.provisional ? "This product was created from an unmatched scan and has little or no history; search_catalog may find a real match." : "",
        "The core evidence is below. Use tools to dig deeper where it matters (history, per-retailer stats, compare_products for a competitor, calculate for any arithmetic), then answer with a full report.",
        ...ledger.items.map(evidenceBlock),
      ].join("\n");
      const run = await runAgent({ provider: config.provider, model: config.full.model, reasoning: config.full.reasoning, system: systemPrompt(), prompt, tools: buildTools(data), output: reportSpec(COMPETITOR_TOOLS), ledger, maxToolTurns: 6, maxRepairs: 2 });
      const final = finalize(productId, scan, ledger, run.ok ? { output: run.output, issues: run.groundingIssues } : { output: null, issues: [`model failed: ${run.error}`] }, ev);
      const { analysisId } = await save(ctx, productId, "full", config.full.model, scan, final, run.usage, ledger, Date.now() - started, data.sampleDataSeen() || product.isSample, now);
      if (jobId) await ctx.runMutation(internal.agent.store.finishJob, { jobId, status: "done" });
      return { analysisId, verdict: final.output.verdict, source: final.source, latencyMs: Date.now() - started, issues: final.issues, turns: run.turns };
    } catch (error) {
      if (jobId) await ctx.runMutation(internal.agent.store.finishJob, { jobId, status: "failed", error: String(error).slice(0, 500) });
      throw error;
    }
  },
});
