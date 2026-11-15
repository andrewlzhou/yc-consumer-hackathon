import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { runQuickPass } from "./agent";

const http = httpRouter();
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

// Phone uploads the screenshot as the raw request body.
// Headers: x-device-id, x-scan-key (client-generated UUID), optional x-need-by (YYYY-MM-DD).
http.route({
  path: "/scan",
  method: "POST",
  handler: httpAction(async (ctx, req) => {
    const deviceId = req.headers.get("x-device-id") ?? "anon";
    const scanKey = req.headers.get("x-scan-key") ?? crypto.randomUUID();
    const needBy = req.headers.get("x-need-by") ?? undefined;
    const imageId = await ctx.storage.store(await req.blob());
    const scanId = await ctx.runMutation(internal.scans.create, { deviceId, scanKey, imageId, needBy });
    try {
      const quick = await runQuickPass(ctx, scanId, { imageId });
      return json({ scanKey, ...quick });
    } catch (e) {
      await ctx.runMutation(internal.scans.patch, { id: scanId, fields: { status: "error", error: String(e) } });
      return json({ scanKey, error: String(e) }, 500);
    }
  }),
});

// App polls this for the full report.
http.route({
  path: "/scan",
  method: "GET",
  handler: httpAction(async (ctx, req) => {
    const key = new URL(req.url).searchParams.get("key");
    if (!key) return json({ error: "missing key" }, 400);
    const s = await ctx.runQuery(internal.scans.byKey, { scanKey: key });
    if (!s) return json({ error: "not found" }, 404);
    return json({ status: s.status, step: s.step, quick: s.quick?.public ?? null, result: s.result ?? null, error: s.error ?? null });
  }),
});

http.route({
  path: "/wishlist",
  method: "POST",
  handler: httpAction(async (ctx, req) => {
    const { deviceId, scanKey, needBy } = await req.json();
    await ctx.runMutation(internal.wishlist.add, { deviceId, scanKey, needBy: needBy || undefined });
    return json({ ok: true });
  }),
});

http.route({
  path: "/wishlist",
  method: "GET",
  handler: httpAction(async (ctx, req) => {
    const deviceId = new URL(req.url).searchParams.get("deviceId") ?? "";
    return json(await ctx.runQuery(internal.wishlist.list, { deviceId }));
  }),
});

// Search tab and the iMessage agent: free text like "AirPods Pro 3" or a product link.
// Body: { "q": string, "deviceId"?: string, "needBy"?: "YYYY-MM-DD" }
http.route({
  path: "/ask",
  method: "POST",
  handler: httpAction(async (ctx, req) => {
    const body = await req.json();
    const q = String(body.q ?? "").trim();
    if (!q) return json({ error: "missing q" }, 400);
    const deviceId = String(body.deviceId ?? req.headers.get("x-device-id") ?? "anon");
    const scanKey = String(body.scanKey ?? crypto.randomUUID());
    const scanId = await ctx.runMutation(internal.scans.create, { deviceId, scanKey, query: q, needBy: body.needBy ?? undefined });
    try {
      const quick = await runQuickPass(ctx, scanId, { query: q });
      return json({ scanKey, ...quick });
    } catch (e) {
      await ctx.runMutation(internal.scans.patch, { id: scanId, fields: { status: "error", error: String(e) } });
      return json({ scanKey, error: String(e) }, 500);
    }
  }),
});

// History tab.
http.route({
  path: "/history",
  method: "GET",
  handler: httpAction(async (ctx, req) => {
    const deviceId = new URL(req.url).searchParams.get("deviceId") ?? "";
    return json(await ctx.runQuery(internal.scans.listByDevice, { deviceId }));
  }),
});

// Search tab "Discover": ?kind=lowest (at or near their lowest ever) or ?kind=deals (biggest real discounts).
http.route({
  path: "/discover",
  method: "GET",
  handler: httpAction(async (ctx, req) => {
    const kind = new URL(req.url).searchParams.get("kind") === "lowest" ? "lowest" : "deals";
    const rows = await ctx.runQuery(internal.products.listRecent, {});
    const items = rows
      .filter((r: any) => r.result?.stats && r.result?.currentPrice)
      .map((r: any) => {
        const { stats, currentPrice } = r.result;
        const discount = stats.median ? (stats.median - currentPrice) / stats.median : 0;
        return { key: r.key, result: r.result, discount, nearLow: currentPrice <= stats.allTimeLow * 1.03 };
      })
      .sort((a: any, b: any) => b.discount - a.discount);
    const picked = items.filter((i: any) => (kind === "lowest" ? i.nearLow : i.discount > 0.05));
    const out = (picked.length ? picked : items).slice(0, 20); // never show an empty list on stage
    return json(out.map((i: any) => ({ key: i.key, discount: Math.round(i.discount * 100), result: i.result })));
  }),
});

// Demo button: run the daily re-check right now.
http.route({
  path: "/recheck",
  method: "POST",
  handler: httpAction(async (ctx) => {
    await ctx.scheduler.runAfter(0, internal.agent.recheckSaved, {});
    return json({ ok: true });
  }),
});

export default http;
