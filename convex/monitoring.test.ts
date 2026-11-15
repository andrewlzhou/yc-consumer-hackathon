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
beforeEach(() => {
  vi.stubEnv("OPENAI_API_KEY", "");
  vi.stubEnv("SERPAPI_API_KEY", "");
});

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

async function seeded() {
  const t = convexTest(schema, modules);
  const { products } = await t.action(internal.seed.run.all, {});
  const productId = Object.values(products)[0] as Id<"products">;
  const state = await t.query(internal.monitoring.ports.readState, { productId, now: Date.now() });
  const watch = (targetPrice?: number) =>
    t.run((ctx) => ctx.db.insert("watchItems", { deviceId: DEVICE, productId, targetPrice, prefs: defaultPrefs(), createdAt: Date.now() }));
  const log = () => t.run((ctx) => ctx.db.query("notificationLog").collect());
  const sent = async () => (await log()).filter((r) => r.status === "sent");
  const record = (price: number, source: "scan" | "api", observedAt = Date.now()) =>
    t.run((ctx) => ctx.db.insert("priceObservations", { productId, retailerSlug: "target", price, inStock: true, observedAt, source }));
  return { t, productId, state: state!, watch, log, sent, record };
}

test("end to end on seeded data: seeded lows are never stated as fact, a lone scan never notifies, a real api price under the target does", async () => {
  const { t, productId, state, watch, sent, record, log } = await seeded();
  expect(state.snapshot.priceSource).toBe("seed");
  expect(state.snapshot.priorLow).toBeUndefined();
  expect(state.snapshot.isSampleData).toBe(true);
  await watch(state.snapshot.currentPrice - 10);

  expect(await t.action(internal.monitoring.check.checkProduct, { productId })).toMatchObject([{ status: "baseline" }]);
  await t.action(internal.monitoring.check.checkProduct, { productId });
  expect(await sent()).toEqual([]);

  await record(state.snapshot.currentPrice - 30, "scan");
  await t.action(internal.monitoring.check.checkProduct, { productId });
  expect(await sent()).toEqual([]);
  await record(state.snapshot.currentPrice - 30, "api");
  expect(await t.action(internal.monitoring.check.checkProduct, { productId })).toMatchObject([{ status: "sent" }]);
  const rows = await sent();
  expect(rows).toHaveLength(1);
  expect(rows[0].trigger).toBe("target_hit");
  expect((await log()).every((r) => r.trigger !== "new_low")).toBe(true);
});

test("a stale price or an out-of-stock latest row is not the current price", async () => {
  const { t, productId, record } = await seeded();
  const now = Date.now();
  await record(10, "api", now - 4 * 24 * 3600_000);
  let state = await t.query(internal.monitoring.ports.readState, { productId, now });
  expect(state!.snapshot.priceSource).toBe("seed");
  await record(150, "api", now - 1000);
  state = await t.query(internal.monitoring.ports.readState, { productId, now });
  expect(state!.snapshot).toMatchObject({ currentPrice: 150, priceSource: "api", priorLow: 10 });

  await t.run((ctx) => ctx.db.insert("priceObservations", { productId, retailerSlug: "target", inStock: false, observedAt: now, source: "api" }));
  state = await t.query(internal.monitoring.ports.readState, { productId, now });
  expect(state!.snapshot.currentPrice).not.toBe(150);
});

test("demo helper: a simulated drop sends one labeled push, leaves the baseline alone, then the cooldown holds", async () => {
  const { t, productId, state, watch, log, sent } = await seeded();
  const itemId = await watch(state.snapshot.currentPrice - 5);
  const price = state.snapshot.currentPrice - 20;

  expect(await t.action(internal.monitoring.simulate.dropPrice, { deviceId: DEVICE, productId, price })).toMatchObject([{ status: "sent" }]);
  expect(await t.action(internal.monitoring.simulate.dropPrice, { deviceId: DEVICE, productId, price: Math.round(price * 95) / 100 })).toMatchObject([
    { status: "suppressed", by: "cooldown" },
  ]);

  const rows = await sent();
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ simulated: true, trigger: "target_hit" });
  expect(rows[0].title.startsWith("[Simulated]")).toBe(true);
  expect(rows[0].body.startsWith("Simulated price drop for demo.")).toBe(true);
  expect((await t.run((ctx) => ctx.db.get(itemId)))!.lastPrice).toBeUndefined();
  expect((await t.run((ctx) => ctx.db.query("priceObservations").collect())).every((h) => h.source === "seed")).toBe(true);
  expect((await log()).length).toBe(2);
});

test("price refresh is skipped while real prices are fresh and reaches SerpApi otherwise", async () => {
  const { t, productId, record } = await seeded();
  expect(await t.action(internal.monitoring.ports.refreshPrices, { productId })).toEqual({ status: "no_key" });
  await record(120, "api", Date.now() - 3600_000);
  expect(await t.action(internal.monitoring.ports.refreshPrices, { productId })).toEqual({ status: "fresh_enough" });
});

test("the sweep asks for a price refresh on the first products only", async () => {
  vi.stubEnv("MONITOR_REFRESH_CAP", "1");
  const t = convexTest(schema, modules);
  const make = (title: string) =>
    t.run((ctx) => ctx.db.insert("products", { title, brand: "A", category: "c", familyKey: title, specs: {}, aliases: [], searchText: title, isSample: false, provisional: false }));
  for (const p of [await make("A"), await make("B")]) await t.run((ctx) => ctx.db.insert("watchItems", { deviceId: DEVICE, productId: p, prefs: defaultPrefs(), createdAt: 1 }));
  expect(await t.mutation(internal.monitoring.check.sweep, {})).toBe(2);
  const jobs = await t.run((ctx) => ctx.db.system.query("_scheduled_functions").collect());
  expect(jobs.map((j) => (j.args[0] as { refresh: boolean }).refresh).sort()).toEqual([false, true]);
});

test("a target price crossing notifies even when the LLM judge would decline; other declines keep the judge's reason", async () => {
  vi.stubEnv("OPENAI_API_KEY", "k");
  vi.stubGlobal("fetch", async () => new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify({ notify: false, why: "not compelling" }) } }] })));
  try {
    const { check, log } = await setup({ targetPrice: 95 });
    await check({ currentPrice: 100 });
    await check({ currentPrice: 94, priorLow: 99 });
    const rows = await log();
    expect(rows.find((r) => r.status === "sent")).toMatchObject({ trigger: "target_hit", judge: "target" });

    const other = await setup();
    await other.check({ currentPrice: 100 });
    await other.check({ currentPrice: 90 });
    expect((await other.log())[0]).toMatchObject({ status: "suppressed", suppressedBy: "judge", judgeWhy: "not compelling" });
  } finally {
    vi.unstubAllGlobals();
  }
});
