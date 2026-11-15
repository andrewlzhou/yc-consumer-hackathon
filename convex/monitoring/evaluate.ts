import { Id } from "../_generated/dataModel";
import { internal } from "../_generated/api";
import { ActionCtx } from "../_generated/server";
import { judge } from "./judge";
import { Snapshot, checkGuardrails, dedupeKey, findCandidates } from "./policy";

export const TRIGGER_LABEL = {
  target_hit: "Target price reached",
  new_low: "New lowest price",
  buy_now_flip: "Now a good time to buy",
  sale_start: "Sale started",
  better_alternative: "Better alternative found",
} as const;

const DEAD_TOKEN_REASONS = ["BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"];

export type EvaluateArgs = {
  productId: Id<"products">;
  title: string;
  snapshot: Snapshot;
  // Simulation targets one device; baseline stands in for a missing real lastPrice/lastVerdict without being stored.
  simulate?: { deviceId: string; baseline?: { price: number; verdict: Snapshot["verdict"] } };
};

// Decides, for each device watching the product, whether the new snapshot deserves a notification, then sends it.
// Candidates and guardrails are code; the LLM only weighs the candidates that survive the guardrails.
export async function evaluate(ctx: ActionCtx, args: EvaluateArgs): Promise<{ deviceId: string; status: string; by?: string }[]> {
  const { snapshot: snap } = args;
  const watchers = await ctx.runQuery(internal.watchlist.items.watchersOf, { productId: args.productId });
  const results: { deviceId: string; status: string; by?: string }[] = [];
  for (const watcher of watchers) {
    if (args.simulate && watcher.deviceId !== args.simulate.deviceId) continue;
    const loaded = await ctx.runQuery(internal.monitoring.state.loadWatcher, { watchId: watcher._id });
    if (!loaded) continue;
    const { item, sent } = loaded;
    const simulated = args.simulate !== undefined;
    const fallback = args.simulate?.baseline;
    const state = {
      targetPrice: item.targetPrice,
      lastPrice: item.lastPrice ?? fallback?.price,
      lastVerdict: item.lastVerdict ?? fallback?.verdict,
      prefs: item.prefs,
    };
    const candidates = state.lastPrice === undefined ? [] : findCandidates(snap, state);
    const blocks = candidates.map((c) =>
      checkGuardrails({ candidate: c, snap, state, sent, key: dedupeKey(item.deviceId, item.productId, c.trigger, snap.currentPrice), now: Date.now(), allowSimulated: simulated }),
    );
    const open = candidates.filter((_, i) => !blocks[i]);
    // A target price is the user's own explicit ask, so crossing it notifies without the LLM's veto.
    const target = open.find((c) => c.trigger === "target_hit");
    const decision = target
      ? { notify: true, trigger: target.trigger, judge: "target", why: target.fact }
      : open.length
        ? await judge({ title: args.title, snap, state, candidates: open })
        : undefined;
    const chosen = decision?.notify && decision.trigger ? { trigger: decision.trigger, judge: decision.judge, why: decision.why } : undefined;
    const label = chosen ? TRIGGER_LABEL[chosen.trigger] : TRIGGER_LABEL[candidates[0]?.trigger ?? "new_low"];
    const result = await ctx.runMutation(internal.monitoring.state.commit, {
      watchId: watcher._id,
      snapshot: snap,
      candidates: open.length ? open : candidates,
      blockedBy: open.length ? undefined : blocks[0],
      chosen,
      declinedWhy: decision && !chosen ? decision.why : undefined,
      title: (simulated ? "[Simulated] " : "") + args.title + " - " + label,
      body: snap.reason,
      simulated,
    });
    results.push({ deviceId: item.deviceId, status: result.status, by: "by" in result ? result.by : undefined });
    if (result.status !== "sent") continue;
    await deliver(ctx, result.logId, result.deviceId, result.token, result.environment, {
      title: (simulated ? "[Simulated] " : "") + args.title + " - " + label,
      body: snap.reason,
      productId: args.productId,
    });
  }
  return results;
}

// APNs when the device has a token and the key is configured; otherwise the notification stays in the inbox
// log, which the app reads (live query) and turns into a local notification.
async function deliver(
  ctx: ActionCtx,
  logId: Id<"notificationLog">,
  deviceId: string,
  token: string | undefined,
  environment: "sandbox" | "production" | undefined,
  message: { title: string; body: string; productId: string },
) {
  if (!token || !environment) {
    await ctx.runMutation(internal.monitoring.state.markDelivery, { logId, channel: "inbox" });
    return;
  }
  const res = await ctx.runAction(internal.monitoring.apns.send, {
    token,
    environment,
    title: message.title,
    body: message.body,
    collapseId: message.productId,
    data: { productId: message.productId },
  });
  if (!res.ok && res.reason && DEAD_TOKEN_REASONS.includes(res.reason)) {
    await ctx.runMutation(internal.watchlist.devices.clearToken, { deviceId, apnsToken: token });
  }
  await ctx.runMutation(internal.monitoring.state.markDelivery, {
    logId,
    channel: res.ok ? "apns" : "inbox",
    error: res.ok ? undefined : res.reason,
  });
}
