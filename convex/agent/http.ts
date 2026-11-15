import type { HttpRouter } from "convex/server";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import { httpAction } from "../_generated/server";
import { isAuthorized } from "../lib/httpAuth";
import type { ProductExtract } from "../lib/contract";
import { rateLimiter } from "./limits";

const json = (body: unknown, status = 200, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...headers } });

type Extract = ProductExtract & { deviceId: string };

// Hand validation of the phone's extract: short strings, plausible prices, a few OCR lines, nothing else.
export function parseExtract(body: unknown): { ok: true; value: Extract } | { ok: false; error: string } {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { ok: false, error: "body must be a JSON object" };
  const b = body as Record<string, unknown>;
  const value: Partial<Extract> = {};
  for (const key of ["deviceId", "title", "retailer", "url"] as const) {
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
  if (!value.deviceId || value.deviceId.length > 100) return { ok: false, error: "deviceId is required" };
  if (value.url && !/^https?:\/\/[^\s/]+\.[^\s]+$/i.test(value.url)) return { ok: false, error: "url must be an http(s) link" };
  if (!value.title && !value.ocrLines?.length && !value.url) return { ok: false, error: "title, ocrLines, or url is required" };
  return { ok: true, value: value as Extract };
}

// Routes: POST /analyze (live verdict card) and GET /report?productId= (detailed stored analysis, on demand).
export function registerAgentRoutes(http: HttpRouter) {
  http.route({
    path: "/analyze",
    method: "POST",
    handler: httpAction(async (ctx, req) => {
      if (!isAuthorized(req)) return json({ error: "unauthorized" }, 401);
      const parsed = parseExtract(await req.json().catch(() => null));
      if (!parsed.ok) return json({ error: parsed.error }, 400);
      for (const limit of [rateLimiter.limit(ctx, "analyzeGlobal"), rateLimiter.limit(ctx, "analyzePerDevice", { key: parsed.value.deviceId })]) {
        const status = await limit;
        if (!status.ok) return json({ error: "rate limited", retryAfterMs: Math.ceil(status.retryAfter) }, 429);
      }
      try {
        const r = await ctx.runAction(internal.agent.analyze.analyzeScan, parsed.value);
        return json(
          r.response,
          200,
          { "server-timing": [`agent;dur=${r.latencyMs};desc="${r.path}"`, ...Object.entries(r.timings).map(([k, ms]) => `${k};dur=${ms}`)].join(", ") },
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
      if (!isAuthorized(req)) return json({ error: "unauthorized" }, 401);
      const productId = new URL(req.url).searchParams.get("productId");
      if (!productId || productId.length > 64) return json({ error: "productId is required" }, 400);
      try {
        const report = await ctx.runQuery(internal.agent.store.report, { productId: productId as Id<"products">, now: Date.now() });
        return report ? json(report) : json({ error: "product not found" }, 404);
      } catch {
        return json({ error: "productId is not valid" }, 400);
      }
    }),
  });
}
