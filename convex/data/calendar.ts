import { v } from "convex/values";
import { internalQuery } from "../_generated/server";
import { DAY } from "./stats";

// Sale events overlapping [from, to]. National events have no retailerSlug and apply everywhere.
export const getSaleCalendar = internalQuery({
  args: { from: v.number(), to: v.number(), retailerSlug: v.optional(v.string()) },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("saleEvents")
      .withIndex("by_startsAt", (q) => q.gte("startsAt", args.from - 30 * DAY).lte("startsAt", args.to))
      .take(200);
    return rows
      .filter((e) => e.endsAt >= args.from)
      .filter((e) => !args.retailerSlug || e.retailerSlug === undefined || e.retailerSlug === args.retailerSlug)
      .map(({ _id, _creationTime, ...e }) => e);
  },
});
