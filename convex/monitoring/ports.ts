// The only file that knows how to reach the data layer and the shopping agent. Rewire here when their APIs change.
import { v } from "convex/values";
import { internalAction } from "../_generated/server";
import { Snapshot } from "./policy";

export type ProductSnapshot = { title: string; snapshot: Snapshot };

// Refreshes prices for a product and re-runs the analysis, returning what monitoring needs.
// Not wired yet: the data and agent threads' functions have not landed on this branch.
export const getSnapshot = internalAction({
  args: { productId: v.id("products") },
  handler: async (_ctx, _args): Promise<ProductSnapshot> => {
    throw new Error("analysis port is not wired to the data and agent functions yet");
  },
});
