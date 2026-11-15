import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  scans: defineTable({
    deviceId: v.string(),
    scanKey: v.string(),
    imageId: v.optional(v.id("_storage")),
    query: v.optional(v.string()), // text searches from the Search tab or iMessage
    status: v.string(), // "working" | "deep" | "done" | "error"
    step: v.string(),
    needBy: v.optional(v.string()),
    productKey: v.optional(v.string()),
    quick: v.optional(v.any()),
    result: v.optional(v.any()),
    error: v.optional(v.string()),
  })
    .index("by_key", ["scanKey"])
    .index("by_device", ["deviceId"]),

  products: defineTable({
    key: v.string(),
    name: v.string(),
    result: v.any(),
    updatedAt: v.number(),
  }).index("by_key", ["key"]),

  wishlist: defineTable({
    deviceId: v.string(),
    scanKey: v.string(),
    productName: v.string(),
    buyDate: v.optional(v.string()),
    targetPrice: v.optional(v.number()),
    needBy: v.optional(v.string()),
    lastPrice: v.optional(v.number()),
    lastRetailer: v.optional(v.string()),
    lastChecked: v.optional(v.number()),
    dropped: v.optional(v.boolean()),
  }).index("by_device", ["deviceId"]),
});
