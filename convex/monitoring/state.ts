import { v } from "convex/values";
import { internalMutation, internalQuery, type QueryCtx } from "../_generated/server";
import type { Id } from "../_generated/dataModel";
import { Candidate, SentRecord, Snapshot, checkGuardrails, dedupeKey } from "./policy";
import { triggerV, verdictV } from "../watchlist/tables";

const snapshotV = v.object({
  currentPrice: v.number(),
  priceSource: v.union(v.literal("scan"), v.literal("api"), v.literal("scrape"), v.literal("seed"), v.literal("simulated")),
  priorLow: v.optional(v.number()),
  verdict: verdictV,
  confidence: v.number(),
  reason: v.string(),
  saleStartDetected: v.optional(v.boolean()),
  isSampleData: v.optional(v.boolean()),
  alternative: v.optional(v.object({ title: v.string(), price: v.number(), savingsPct: v.number() })),
});
export { snapshotV };

// Sent rows only, read through the status index so suppressed rows never push older sends out of the window.
async function sentRecords(ctx: QueryCtx, deviceId: string, productId: Id<"products">): Promise<SentRecord[]> {
  const rows = await ctx.db
    .query("notificationLog")
    .withIndex("by_device_and_product_and_status_and_createdAt", (q) => q.eq("deviceId", deviceId).eq("productId", productId).eq("status", "sent"))
    .order("desc")
    .take(50);
  return rows.map((r) => ({ createdAt: r.createdAt, price: r.price, trigger: r.trigger, dedupeKey: r.dedupeKey }));
}

// Everything the action needs to decide for one watcher: its state, prior sends and the device's push token.
export const loadWatcher = internalQuery({
  args: { watchId: v.id("watchItems") },
  handler: async (ctx, args) => {
    const item = await ctx.db.get(args.watchId);
    if (!item) return null;
    const device = await ctx.db.query("devices").withIndex("by_device", (q) => q.eq("deviceId", item.deviceId)).unique();
    return { item, sent: await sentRecords(ctx, item.deviceId, item.productId), device };
  },
});

// Records one decision and, for real checks only, the watcher's new baseline. A simulated check never moves the
// baseline, so the next real check still compares against the last real price. Guardrails run again here, inside
// the transaction, so two overlapping checks cannot both send.
export const commit = internalMutation({
  args: {
    watchId: v.id("watchItems"),
    snapshot: snapshotV,
    candidates: v.array(v.object({ trigger: triggerV, fact: v.string() })),
    blockedBy: v.optional(v.string()),
    chosen: v.optional(v.object({ trigger: triggerV, judge: v.string(), why: v.string() })),
    declinedWhy: v.optional(v.string()),
    title: v.string(),
    body: v.string(),
    simulated: v.boolean(),
  },
  handler: async (ctx, args) => {
    const item = await ctx.db.get(args.watchId);
    if (!item) return { status: "gone" as const };
    const now = Date.now();
    const snap = args.snapshot as Snapshot;
    const baseline = item.lastPrice === undefined && !args.simulated;
    if (!args.simulated) {
      await ctx.db.patch(item._id, {
        lastPrice: snap.currentPrice,
        lastVerdict: snap.verdict,
        lastReason: snap.reason,
        lastCheckedAt: now,
      });
    }
    if (baseline || args.candidates.length === 0) return { status: baseline ? ("baseline" as const) : ("quiet" as const) };

    const sent = await sentRecords(ctx, item.deviceId, item.productId);
    const state = { targetPrice: item.targetPrice, lastPrice: item.lastPrice, lastVerdict: item.lastVerdict, prefs: item.prefs };
    const log = (c: Candidate, status: "sent" | "suppressed", suppressedBy: string | undefined, judge: string, why: string) =>
      ctx.db.insert("notificationLog", {
        deviceId: item.deviceId,
        productId: item.productId,
        trigger: c.trigger,
        status,
        suppressedBy,
        title: args.title,
        body: args.body,
        price: snap.currentPrice,
        verdict: snap.verdict,
        dedupeKey: dedupeKey(item.deviceId, item.productId, c.trigger, snap.currentPrice),
        judge,
        judgeWhy: why,
        simulated: args.simulated,
        acknowledged: false,
        createdAt: now,
      });

    const first = args.candidates[0];
    if (args.blockedBy) {
      await log(first, "suppressed", args.blockedBy, "guardrails", "blocked before judgment");
      return { status: "suppressed" as const, by: args.blockedBy };
    }
    if (!args.chosen) {
      await log(first, "suppressed", "judge", "judge", args.declinedWhy ?? "judge declined every candidate");
      return { status: "suppressed" as const, by: "judge" };
    }
    const candidate = args.candidates.find((c) => c.trigger === args.chosen!.trigger) ?? first;
    const key = dedupeKey(item.deviceId, item.productId, candidate.trigger, snap.currentPrice);
    const block = checkGuardrails({ candidate, snap, state, sent, key, now, allowSimulated: args.simulated });
    if (block) {
      await log(candidate, "suppressed", block, args.chosen.judge, args.chosen.why);
      return { status: "suppressed" as const, by: block };
    }
    const logId = await log(candidate, "sent", undefined, args.chosen.judge, args.chosen.why);
    const device = await ctx.db.query("devices").withIndex("by_device", (q) => q.eq("deviceId", item.deviceId)).unique();
    return { status: "sent" as const, logId, deviceId: item.deviceId, token: device?.apnsToken, environment: device?.environment };
  },
});

export const markDelivery = internalMutation({
  args: { logId: v.id("notificationLog"), channel: v.union(v.literal("apns"), v.literal("inbox")), error: v.optional(v.string()) },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.logId, { channel: args.channel, deliveryError: args.error });
  },
});
