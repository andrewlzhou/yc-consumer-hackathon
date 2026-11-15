import { httpAction } from "../_generated/server";
import { api } from "../_generated/api";
import type { HttpRouter } from "convex/server";
import { ConvexError } from "convex/values";
import type { Id } from "../_generated/dataModel";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

// Anonymous deviceId is the only identity. If APP_API_KEY is set, requests must send it as x-api-key.
function wrap(handler: (ctx: Parameters<Parameters<typeof httpAction>[0]>[0], input: Record<string, unknown>) => Promise<unknown>) {
  return httpAction(async (ctx, req) => {
    const key = process.env.APP_API_KEY;
    if (key && req.headers.get("x-api-key") !== key) return json({ error: "unauthorized" }, 401);
    const url = new URL(req.url);
    let input: Record<string, unknown> = Object.fromEntries(url.searchParams);
    if (req.method !== "GET") {
      const body: unknown = await req.json().catch(() => null);
      if (typeof body !== "object" || body === null || Array.isArray(body)) return json({ error: "body must be a JSON object" }, 400);
      input = body as Record<string, unknown>;
    }
    try {
      return json(await handler(ctx, input));
    } catch (e) {
      if (e instanceof ConvexError) return json({ error: String(e.data) }, 400);
      return json({ error: "invalid request" }, 400);
    }
  });
}

const str = (v: unknown, name: string) => {
  if (typeof v !== "string" || !v) throw new ConvexError(name + " is required");
  return v;
};
const optNumber = (v: unknown, name: string) => {
  if (v === undefined || v === null) return v as undefined | null;
  if (typeof v !== "number") throw new ConvexError(name + " must be a number or null");
  return v;
};

// Routes: GET /watchlist, POST /watchlist/save, POST /watchlist/remove, POST /watchlist/device,
// GET /watchlist/notifications, POST /watchlist/notifications/ack.
export function registerWatchlistRoutes(http: HttpRouter) {
  http.route({
    path: "/watchlist",
    method: "GET",
    handler: wrap((ctx, i) => ctx.runQuery(api.watchlist.items.list, { deviceId: str(i.deviceId, "deviceId") })),
  });
  http.route({
    path: "/watchlist/save",
    method: "POST",
    handler: wrap(async (ctx, i) => {
      const prefs = i.prefs !== undefined && typeof i.prefs === "object" ? (i.prefs as Record<string, boolean>) : undefined;
      const id = await ctx.runMutation(api.watchlist.items.save, {
        deviceId: str(i.deviceId, "deviceId"),
        productId: str(i.productId, "productId") as Id<"products">,
        targetPrice: optNumber(i.targetPrice, "targetPrice"),
        prefs,
      });
      return { id };
    }),
  });
  http.route({
    path: "/watchlist/remove",
    method: "POST",
    handler: wrap(async (ctx, i) => ({
      removed: await ctx.runMutation(api.watchlist.items.remove, { deviceId: str(i.deviceId, "deviceId"), productId: str(i.productId, "productId") as Id<"products"> }),
    })),
  });
  http.route({
    path: "/watchlist/device",
    method: "POST",
    handler: wrap(async (ctx, i) => {
      await ctx.runMutation(api.watchlist.devices.register, {
        deviceId: str(i.deviceId, "deviceId"),
        apnsToken: typeof i.apnsToken === "string" ? i.apnsToken : undefined,
        environment: i.environment === "production" ? "production" : "sandbox",
      });
      return { ok: true };
    }),
  });
  http.route({
    path: "/watchlist/notifications",
    method: "GET",
    handler: wrap((ctx, i) => ctx.runQuery(api.watchlist.inbox.pending, { deviceId: str(i.deviceId, "deviceId") })),
  });
  http.route({
    path: "/watchlist/notifications/ack",
    method: "POST",
    handler: wrap(async (ctx, i) => {
      if (!Array.isArray(i.ids)) throw new ConvexError("ids must be an array");
      await ctx.runMutation(api.watchlist.inbox.acknowledge, { deviceId: str(i.deviceId, "deviceId"), ids: i.ids as Id<"notificationLog">[] });
      return { ok: true };
    }),
  });
}
