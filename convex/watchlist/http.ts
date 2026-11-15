import type { HttpRouter } from "convex/server";
import { ConvexError } from "convex/values";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import { httpAction, type ActionCtx } from "../_generated/server";
import { TRIGGERS } from "../monitoring/policy";
import { isAuthorized } from "../lib/httpAuth";

export const RATE_LIMIT = { limit: 60, windowMs: 60_000 };

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

const str = (v: unknown, name: string) => {
  if (typeof v !== "string" || !v || v.length > 200) throw new ConvexError(name + " is required (at most 200 characters)");
  return v;
};
const optNumber = (v: unknown, name: string) => {
  if (v === undefined || v === null) return v as undefined | null;
  if (typeof v !== "number" || !Number.isFinite(v)) throw new ConvexError(name + " must be a number or null");
  return v;
};
function parsePrefs(v: unknown) {
  if (v === undefined) return undefined;
  if (typeof v !== "object" || v === null || Array.isArray(v)) throw new ConvexError("prefs must be an object");
  const out: Record<string, boolean> = {};
  for (const [k, val] of Object.entries(v)) {
    if (!(TRIGGERS as string[]).includes(k) || typeof val !== "boolean") throw new ConvexError("prefs." + k + " is not a known boolean preference");
    out[k] = val;
  }
  return out;
}

// Order: shared API key (lib/httpAuth, fail closed unless APP_ALLOW_UNAUTHENTICATED=1), per-device rate limit, then the handler. The anonymous deviceId is the only
// identity and is not authentication; the watchlist functions are internal, so this wrapper is the only way in.
function wrap(handler: (ctx: ActionCtx, input: Record<string, unknown>) => Promise<unknown>) {
  return httpAction(async (ctx, req) => {
    if (!process.env.APP_API_KEY && process.env.APP_ALLOW_UNAUTHENTICATED !== "1")
      return json({ error: "unauthorized: APP_API_KEY is not configured on the server" }, 401);
    if (!isAuthorized(req)) return json({ error: "unauthorized" }, 401);
    let input: Record<string, unknown> = Object.fromEntries(new URL(req.url).searchParams);
    if (req.method !== "GET") {
      const body: unknown = await req.json().catch(() => null);
      if (typeof body !== "object" || body === null || Array.isArray(body)) return json({ error: "body must be a JSON object" }, 400);
      input = body as Record<string, unknown>;
    }
    try {
      const deviceId = str(input.deviceId, "deviceId");
      if (!(await ctx.runMutation(internal.watchlist.rateLimit.hit, { key: "device:" + deviceId, ...RATE_LIMIT }))) return json({ error: "rate limit exceeded" }, 429);
      return json(await handler(ctx, { ...input, deviceId }));
    } catch (e) {
      if (e instanceof ConvexError) return json({ error: String(e.data) }, 400);
      console.error("watchlist route failed", e instanceof Error ? e.message : "unknown error");
      return json({ error: "internal error" }, 500);
    }
  });
}

// Routes: GET /watchlist, POST /watchlist/save, POST /watchlist/remove, POST /watchlist/device,
// GET /watchlist/notifications, POST /watchlist/notifications/ack. All need the x-api-key header.
export function registerWatchlistRoutes(http: HttpRouter) {
  http.route({
    path: "/watchlist",
    method: "GET",
    handler: wrap((ctx, i) => ctx.runQuery(internal.watchlist.items.list, { deviceId: i.deviceId as string })),
  });
  http.route({
    path: "/watchlist/save",
    method: "POST",
    handler: wrap(async (ctx, i) => ({
      id: await ctx.runMutation(internal.watchlist.items.save, {
        deviceId: i.deviceId as string,
        productId: str(i.productId, "productId") as Id<"products">,
        targetPrice: optNumber(i.targetPrice, "targetPrice"),
        prefs: parsePrefs(i.prefs),
      }),
    })),
  });
  http.route({
    path: "/watchlist/remove",
    method: "POST",
    handler: wrap(async (ctx, i) => ({
      removed: await ctx.runMutation(internal.watchlist.items.remove, { deviceId: i.deviceId as string, productId: str(i.productId, "productId") as Id<"products"> }),
    })),
  });
  http.route({
    path: "/watchlist/device",
    method: "POST",
    handler: wrap(async (ctx, i) => {
      if (i.environment !== undefined && i.environment !== "sandbox" && i.environment !== "production") throw new ConvexError("environment must be sandbox or production");
      if (i.apnsToken !== undefined && i.apnsToken !== null && typeof i.apnsToken !== "string") throw new ConvexError("apnsToken must be a string or null");
      await ctx.runMutation(internal.watchlist.devices.register, { deviceId: i.deviceId as string, apnsToken: i.apnsToken as string | null | undefined, environment: i.environment });
      return { ok: true };
    }),
  });
  http.route({
    path: "/watchlist/notifications",
    method: "GET",
    handler: wrap((ctx, i) => ctx.runQuery(internal.watchlist.inbox.pending, { deviceId: i.deviceId as string })),
  });
  http.route({
    path: "/watchlist/notifications/ack",
    method: "POST",
    handler: wrap(async (ctx, i) => {
      if (!Array.isArray(i.ids) || i.ids.length > 50 || !i.ids.every((x) => typeof x === "string")) throw new ConvexError("ids must be an array of at most 50 strings");
      await ctx.runMutation(internal.watchlist.inbox.acknowledge, { deviceId: i.deviceId as string, ids: i.ids as Id<"notificationLog">[] });
      return { ok: true };
    }),
  });
}
