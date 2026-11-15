/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { beforeEach, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import schema from "./schema";
import { Snapshot, defaultPrefs } from "./monitoring/policy";

const modules = import.meta.glob("./**/*.ts");
const DEVICE = "device-test-0001";

// Tests use the deterministic rules judge even when a real key is in the environment.
beforeEach(() => vi.stubEnv("OPENAI_API_KEY", ""));

async function setup(over: { targetPrice?: number; prefs?: ReturnType<typeof defaultPrefs> } = {}) {
  const t = convexTest(schema, modules);
  const productId = await t.run((ctx) =>
    ctx.db.insert("products", {
      title: "Acme Headphones",
      brand: "Acme",
      category: "audio",
      familyKey: "acme-hp",
      specs: {},
      aliases: [],
      searchText: "Acme Headphones",
      isSample: false,
      provisional: false,
    }),
  );
  await t.run((ctx) =>
    ctx.db.insert("watchItems", { deviceId: DEVICE, productId, targetPrice: over.targetPrice, prefs: over.prefs ?? defaultPrefs(), createdAt: Date.now() }),
  );
  const check = (snapshot: Partial<Snapshot>, simulateDeviceId?: string) =>
    t.action(internal.monitoring.check.evaluateSnapshot, {
      productId,
      title: "Acme Headphones",
      snapshot: { currentPrice: 100, priceSource: "scan", priorLow: 95, verdict: "WAIT", confidence: 0.8, reason: "Reason line from the agent.", ...snapshot },
      simulateDeviceId,
    });
  const log = () => t.run((ctx) => ctx.db.query("notificationLog").collect());
  return { t, productId, check, log };
}

test("first check only records a baseline", async () => {
  const { check, log } = await setup({ targetPrice: 80 });
  expect(await check({ currentPrice: 70 })).toMatchObject([{ status: "baseline" }]);
  expect(await log()).toEqual([]);
});

test("a real drop notifies with the agent's reason, then the cooldown blocks a repeat", async () => {
  const { check, log } = await setup();
  await check({ currentPrice: 100 });
  expect(await check({ currentPrice: 90, reason: "Lowest price in 6 months." })).toMatchObject([{ status: "sent" }]);
  const [sent] = await log();
  expect(sent).toMatchObject({ status: "sent", trigger: "new_low", body: "Lowest price in 6 months.", channel: "inbox", simulated: false, judge: "rules" });

  expect(await check({ currentPrice: 88, priorLow: 90 })).toMatchObject([{ status: "suppressed", by: "cooldown" }]);
  const rows = await log();
  expect(rows.filter((r) => r.status === "sent")).toHaveLength(1);
  expect(rows.find((r) => r.status === "suppressed")).toMatchObject({ suppressedBy: "cooldown" });
});

test("target price crossing fires target_hit", async () => {
  const { check, log } = await setup({ targetPrice: 95 });
  await check({ currentPrice: 100 });
  await check({ currentPrice: 94, priorLow: 90 });
  expect((await log())[0]).toMatchObject({ status: "sent", trigger: "target_hit" });
});

test("seed-derived prices never send", async () => {
  const { check, log } = await setup();
  await check({ currentPrice: 100, priceSource: "seed" });
  await check({ currentPrice: 80, priceSource: "seed" });
  expect((await log()).filter((r) => r.status === "sent")).toEqual([]);
});

test("a disabled preference never sends", async () => {
  const { check, log } = await setup({ prefs: { ...defaultPrefs(), new_low: false } });
  await check({ currentPrice: 100 });
  await check({ currentPrice: 90 });
  expect((await log()).filter((r) => r.status === "sent")).toEqual([]);
});

test("simulated drop sends only to the requesting device and is labeled", async () => {
  const { check, log, t, productId } = await setup();
  await t.run((ctx) => ctx.db.insert("watchItems", { deviceId: "device-other-0002", productId, prefs: defaultPrefs(), lastPrice: 100, createdAt: 1 }));
  await check({ currentPrice: 100 });
  const res = await check({ currentPrice: 70, priceSource: "simulated" }, DEVICE);
  expect(res).toMatchObject([{ deviceId: DEVICE, status: "sent" }]);
  const rows = await log();
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ simulated: true, deviceId: DEVICE });
  expect(rows[0].title.startsWith("[Simulated]")).toBe(true);
});

test("a simulated price outside the demo helper never sends", async () => {
  const { check, log } = await setup();
  await check({ currentPrice: 100 });
  await check({ currentPrice: 70, priceSource: "simulated" });
  expect((await log()).filter((r) => r.status === "sent")).toEqual([]);
});

test("end to end on seeded data: seed history never sends, a real scan drop does", async () => {
  const t = convexTest(schema, modules);
  const { products } = await t.mutation(internal.seed.run.all, {});
  const productId = Object.values(products)[0] as Id<"products">;
  await t.run((ctx) => ctx.db.insert("watchItems", { deviceId: DEVICE, productId, prefs: defaultPrefs(), createdAt: Date.now() }));
  const log = () => t.run((ctx) => ctx.db.query("notificationLog").collect());

  expect(await t.action(internal.monitoring.check.checkProduct, { productId })).toMatchObject([{ status: "baseline" }]);
  await t.action(internal.monitoring.check.checkProduct, { productId });
  expect((await log()).filter((r) => r.status === "sent")).toEqual([]);

  const state = await t.query(internal.monitoring.ports.readState, { productId, now: Date.now() });
  const current = state!.snapshot;
  expect(current.priceSource).toBe("seed");
  await t.mutation(internal.data.prices.recordObservation, {
    productId,
    retailer: "target",
    price: Math.min(current.currentPrice, current.priorLow ?? current.currentPrice) - 15,
    source: "scan",
  });
  const res = await t.action(internal.monitoring.check.checkProduct, { productId });
  expect(res).toMatchObject([{ status: "sent" }]);
  expect((await log()).filter((r) => r.status === "sent")).toHaveLength(1);
});

test("demo helper: simulated drop on a seeded product sends a labeled push once, then the cooldown holds", async () => {
  const t = convexTest(schema, modules);
  const { products } = await t.mutation(internal.seed.run.all, {});
  const productId = Object.values(products)[0] as Id<"products">;
  await t.run((ctx) => ctx.db.insert("watchItems", { deviceId: DEVICE, productId, prefs: defaultPrefs(), createdAt: Date.now() }));
  const state = await t.query(internal.monitoring.ports.readState, { productId, now: Date.now() });
  const low = Math.min(state!.snapshot.currentPrice, state!.snapshot.priorLow ?? Infinity);

  const first = await t.action(internal.monitoring.simulate.dropPrice, { deviceId: DEVICE, productId, price: low - 20 });
  expect(first).toMatchObject([{ status: "sent" }]);
  const second = await t.action(internal.monitoring.simulate.dropPrice, { deviceId: DEVICE, productId, price: Math.round((low - 20) * 95) / 100 });
  expect(second).toMatchObject([{ status: "suppressed", by: "cooldown" }]);

  const rows = await t.run((ctx) => ctx.db.query("notificationLog").collect());
  expect(rows.filter((r) => r.status === "sent")).toHaveLength(1);
  expect(rows[0]).toMatchObject({ simulated: true });
  expect(rows[0].title.startsWith("[Simulated]")).toBe(true);
  expect(rows[0].body.startsWith("Simulated price drop for demo.")).toBe(true);
  const history = await t.run((ctx) => ctx.db.query("priceObservations").collect());
  expect(history.every((h) => h.source === "seed")).toBe(true);
});
