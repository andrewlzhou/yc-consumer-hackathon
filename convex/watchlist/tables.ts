// Monitoring tables. schema.ts spreads this object so this thread's tables stay in one block.
import { defineTable } from "convex/server";
import { v } from "convex/values";
import { verdictValidator as verdictV } from "../lib/contract";

export { verdictV };

export const triggerV = v.union(
  v.literal("target_hit"),
  v.literal("new_low"),
  v.literal("buy_now_flip"),
  v.literal("sale_start"),
  v.literal("better_alternative"),
);
export const prefsV = v.object({
  target_hit: v.boolean(),
  new_low: v.boolean(),
  buy_now_flip: v.boolean(),
  sale_start: v.boolean(),
  better_alternative: v.boolean(),
});

export const watchlistTables = {
  // deviceId is an anonymous client-generated id, not authentication. Anyone who knows it can edit that list.
  devices: defineTable({
    deviceId: v.string(),
    apnsToken: v.optional(v.string()),
    environment: v.union(v.literal("sandbox"), v.literal("production")),
    updatedAt: v.number(),
  }).index("by_device", ["deviceId"]),

  watchItems: defineTable({
    deviceId: v.string(),
    productId: v.id("products"),
    targetPrice: v.optional(v.number()),
    prefs: prefsV,
    lastPrice: v.optional(v.number()),
    lastVerdict: v.optional(verdictV),
    lastReason: v.optional(v.string()),
    lastCheckedAt: v.optional(v.number()),
    createdAt: v.number(),
  })
    .index("by_device_and_product", ["deviceId", "productId"])
    .index("by_product", ["productId"]),

  // One row per notification decision, sent or suppressed. Drives cooldown, dedupe, debugging and the in-app inbox fallback.
  notificationLog: defineTable({
    deviceId: v.string(),
    productId: v.id("products"),
    trigger: triggerV,
    status: v.union(v.literal("sent"), v.literal("suppressed")),
    suppressedBy: v.optional(v.string()),
    channel: v.optional(v.union(v.literal("apns"), v.literal("inbox"))),
    deliveryError: v.optional(v.string()),
    title: v.string(),
    body: v.string(),
    price: v.number(),
    verdict: verdictV,
    dedupeKey: v.string(),
    judge: v.string(),
    judgeWhy: v.string(),
    simulated: v.boolean(),
    acknowledged: v.boolean(),
    createdAt: v.number(),
  })
    .index("by_device_and_product_and_status_and_createdAt", ["deviceId", "productId", "status", "createdAt"])
    .index("by_device_and_status_and_acknowledged_and_createdAt", ["deviceId", "status", "acknowledged", "createdAt"]),

  // Fixed-window request counters for the HTTP rate limit, one row per key and window.
  rateLimits: defineTable({ key: v.string(), windowStart: v.number(), count: v.number() }).index("by_key", ["key"]),
};
