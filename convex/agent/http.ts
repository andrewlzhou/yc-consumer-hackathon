import type { HttpRouter } from "convex/server";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import { httpAction } from "../_generated/server";

const json = (body: unknown, status = 200, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...headers } });

// Same shared key as the watchlist routes: when APP_API_KEY is set, requests must send it as x-api-key.
const authorized = (req: Request) => !process.env.APP_API_KEY || req.headers.get("x-api-key") === process.env.APP_API_KEY;

type Extract = { title?: string; retailer?: string; currentPrice?: number; originalPrice?: number; url?: string; ocrLines?: string[]; capturedAt?: number };

// Hand validation of the phone's extract: short strings, plausible prices, a few OCR lines, nothing else.
export function parseExtract(body: unknown): { ok: true; value: Extract } | { ok: false; error: string } {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { ok: false, error: "body must be a JSON object" };
  const b = body as Record<string, unknown>;
  const value: Extract = {};
  for (const key of ["title", "retailer", "url"] as const) {
    const x = b[key];
    if (x === undefined || x === null) continue;
    if (typeof x !== "string" || x.length > 500) return { ok: false, error: `${key} must be a string of at most 500 characters` };
    if (x.trim()) value[key] = x.trim();
  }
  for (const key of ["currentPrice", "originalPrice", "capturedAt"] as const) {
    const x = b[key];
    if (x === undefined || x === null) continue;
    const max = key === "capturedAt" ? 1e13 : 100_000;
    if (typeof x !== "number" || !Number.isFinite(x) || x <= 0 || x > max) return { ok: false, error: `${key} must be a positive number` };
    value[key] = x;
  }
  if (b.ocrLines !== undefined && b.ocrLines !== null) {
    if (!Array.isArray(b.ocrLines) || b.ocrLines.length > 20 || !b.ocrLines.every((l) => typeof l === "string" && l.length <= 200))
      return { ok: false, error: "ocrLines must be at most 20 strings of at most 200 characters" };
    value.ocrLines = b.ocrLines as string[];
  }
  if (!value.title && !value.ocrLines?.length) return { ok: false, error: "title or ocrLines is required" };
  return { ok: true, value };
}

// Routes: POST /analyze (live verdict card) and GET /report?productId= (detailed stored analysis, on demand).
export function registerAgentRoutes(http: HttpRouter) {
  http.route({
    path: "/analyze",
    method: "POST",
    handler: httpAction(async (ctx, req) => {
      if (!authorized(req)) return json({ error: "unauthorized" }, 401);
      const parsed = parseExtract(await req.json().catch(() => null));
      if (!parsed.ok) return json({ error: parsed.error }, 400);
      try {
        const r = await ctx.runAction(internal.agent.analyze.analyzeScan, parsed.value);
        return json(
          { productId: r.productId, matchedTitle: r.matchedTitle, verdict: r.verdict, reason: r.reason, confidence: r.confidence, isSampleData: r.isSampleData, reportStatus: r.reportStatus },
          200,
          { "server-timing": `agent;dur=${r.latencyMs};desc="${r.path}"` },
        );
      } catch {
        return json({ error: "analysis failed" }, 500);
      }
    }),
  });
  http.route({
    path: "/report",
    method: "GET",
    handler: httpAction(async (ctx, req) => {
      if (!authorized(req)) return json({ error: "unauthorized" }, 401);
      const productId = new URL(req.url).searchParams.get("productId");
      if (!productId || productId.length > 64) return json({ error: "productId is required" }, 400);
      try {
        const report = await ctx.runQuery(internal.agent.store.report, { productId: productId as Id<"products"> });
        return report ? json(report) : json({ error: "product not found" }, 404);
      } catch {
        return json({ error: "productId is not valid" }, 400);
      }
    }),
  });
}
