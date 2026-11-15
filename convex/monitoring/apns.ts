"use node";
import { v } from "convex/values";
import { internalAction } from "../_generated/server";
import { apnsConfigFromEnv, sendApns, sendRaw, signProviderToken } from "./apnsClient";

const environment = v.union(v.literal("sandbox"), v.literal("production"));

// Sends one push. Returns a result instead of throwing so the caller can log the outcome.
export const send = internalAction({
  args: { token: v.string(), environment, title: v.string(), body: v.string(), collapseId: v.optional(v.string()), data: v.optional(v.any()) },
  handler: async (_ctx, args) => {
    const cfg = apnsConfigFromEnv();
    if (!cfg) return { ok: false, status: 0, reason: "apns_not_configured" };
    try {
      return await sendApns(cfg, args.environment, args.token, { title: args.title, body: args.body, data: args.data }, args.collapseId);
    } catch (e) {
      return { ok: false, status: 0, reason: e instanceof Error ? e.message : "apns_request_failed" };
    }
  },
});

// Run once on a real deployment: a throwaway key proves the Node runtime reaches APNs over HTTP/2.
// Expected result: status 403, reason InvalidProviderToken.
export const probe = internalAction({
  args: {},
  handler: async () => {
    const { generateKeyPairSync } = await import("node:crypto");
    const { privateKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
    const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
    const jwt = signProviderToken({ keyId: "PROBE00000", teamId: "PROBE00000", privateKey: pem });
    return sendRaw({
      host: "https://api.sandbox.push.apple.com",
      deviceToken: "0".repeat(64),
      jwt,
      topic: "com.example.probe",
      message: { title: "probe", body: "probe" },
    });
  },
});
