/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

const modules = import.meta.glob("./**/*.ts");
const D = "device-wl-0001";

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

async function product(t: ReturnType<typeof convexTest>, title = "Acme Headphones") {
  return await t.run((ctx) =>
    ctx.db.insert("products", { title, brand: "Acme", category: "audio", familyKey: title, specs: {}, aliases: [], searchText: title, isSample: true, provisional: false }),
  );
}

test("save, edit, list and remove a watched product", async () => {
  const t = convexTest(schema, modules);
  const productId = await product(t);
  await t.mutation(api.watchlist.items.save, { deviceId: D, productId, targetPrice: 120 });
  await t.mutation(api.watchlist.items.save, { deviceId: D, productId, prefs: { sale_start: false } });
  let [item] = await t.query(api.watchlist.items.list, { deviceId: D });
  expect(item).toMatchObject({ targetPrice: 120, prefs: { sale_start: false, new_low: true } });

  await t.mutation(api.watchlist.items.save, { deviceId: D, productId, targetPrice: null });
  [item] = await t.query(api.watchlist.items.list, { deviceId: D });
  expect(item.targetPrice).toBeUndefined();

  expect(await t.query(api.watchlist.items.list, { deviceId: "device-other-9" })).toEqual([]);
  expect(await t.mutation(api.watchlist.items.remove, { deviceId: D, productId })).toBe(true);
  expect(await t.query(api.watchlist.items.list, { deviceId: D })).toEqual([]);
});

test("rejects bad device ids and target prices", async () => {
  const t = convexTest(schema, modules);
  const productId = await product(t);
  await expect(t.mutation(api.watchlist.items.save, { deviceId: "x", productId })).rejects.toThrow();
  await expect(t.mutation(api.watchlist.items.save, { deviceId: D, productId, targetPrice: -5 })).rejects.toThrow();
});

test("device registration validates the token and upserts", async () => {
  const t = convexTest(schema, modules);
  await expect(t.mutation(api.watchlist.devices.register, { deviceId: D, apnsToken: "not hex!", environment: "sandbox" })).rejects.toThrow();
  await t.mutation(api.watchlist.devices.register, { deviceId: D, apnsToken: "ab".repeat(32), environment: "sandbox" });
  await t.mutation(api.watchlist.devices.register, { deviceId: D, apnsToken: "cd".repeat(32), environment: "production" });
  const rows = await t.run((ctx) => ctx.db.query("devices").collect());
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ apnsToken: "cd".repeat(32), environment: "production" });
});

test("the sweep schedules one task per distinct watched product", async () => {
  const t = convexTest(schema, modules);
  const a = await product(t, "A");
  const b = await product(t, "B");
  for (const [dev, p] of [["device-aaaa-0001", a], ["device-bbbb-0002", a], ["device-aaaa-0001", b]] as const) {
    await t.mutation(api.watchlist.items.save, { deviceId: dev, productId: p });
  }
  const count = () => t.run(async (ctx) => (await ctx.db.system.query("_scheduled_functions").collect()).length);
  const before = await count();
  expect(await t.mutation(internal.monitoring.check.sweep, {})).toBe(2);
  expect((await count()) - before).toBe(2);
});

test("inbox lists unacknowledged sent notifications for that device only", async () => {
  const t = convexTest(schema, modules);
  const productId = await product(t);
  const row = (deviceId: string, status: "sent" | "suppressed") => ({
    deviceId, productId, trigger: "new_low" as const, status, title: "t", body: "b", price: 1, verdict: "WAIT" as const,
    dedupeKey: "k", judge: "rules", judgeWhy: "w", simulated: false, acknowledged: false, createdAt: Date.now(),
  });
  const ids = await t.run(async (ctx) => [
    await ctx.db.insert("notificationLog", row(D, "sent")),
    await ctx.db.insert("notificationLog", row(D, "suppressed")),
    await ctx.db.insert("notificationLog", row("device-other-9", "sent")),
  ]);
  expect(await t.query(api.watchlist.inbox.pending, { deviceId: D })).toHaveLength(1);
  await t.mutation(api.watchlist.inbox.acknowledge, { deviceId: "device-other-9", ids: [ids[0]] });
  expect(await t.query(api.watchlist.inbox.pending, { deviceId: D })).toHaveLength(1);
  await t.mutation(api.watchlist.inbox.acknowledge, { deviceId: D, ids: [ids[0]] });
  expect(await t.query(api.watchlist.inbox.pending, { deviceId: D })).toEqual([]);
});
