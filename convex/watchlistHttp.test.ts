/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { RATE_LIMIT } from "./watchlist/http";
import { modules } from "./test.setup";

const KEY = "test-app-key";
const D = "device-http-0001";

beforeEach(() => {
  vi.useFakeTimers();
  vi.stubEnv("APP_ALLOW_UNAUTHENTICATED", "");
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

const call = (t: ReturnType<typeof convexTest>, path: string, init: { method?: string; body?: unknown; key?: string | null } = {}) =>
  t.fetch(path, {
    method: init.method ?? "GET",
    headers: { "content-type": "application/json", ...(init.key === null ? {} : { "x-api-key": init.key ?? KEY }) },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });

async function product(t: ReturnType<typeof convexTest>) {
  return await t.run((ctx) =>
    ctx.db.insert("products", { title: "Acme", brand: "Acme", category: "audio", familyKey: "acme", specs: {}, aliases: [], searchText: "Acme", isSample: true, provisional: false }),
  );
}

test("routes refuse every request when APP_API_KEY is not configured", async () => {
  const t = convexTest(schema, modules);
  const res = await call(t, "/watchlist?deviceId=" + D, { key: KEY });
  expect(res.status).toBe(401);
  expect((await res.json()).error).toContain("APP_API_KEY");
});

test("routes require the exact key", async () => {
  vi.stubEnv("APP_API_KEY", KEY);
  const t = convexTest(schema, modules);
  expect((await call(t, "/watchlist?deviceId=" + D, { key: null })).status).toBe(401);
  expect((await call(t, "/watchlist?deviceId=" + D, { key: KEY + "x" })).status).toBe(401);
  expect((await call(t, "/watchlist?deviceId=" + D, { key: KEY.slice(0, -1) })).status).toBe(401);
  expect((await call(t, "/watchlist?deviceId=" + D)).status).toBe(200);
});

test("the watchlist functions are internal: they are not on the public api object", () => {
  // @ts-expect-error watchlist functions must stay internal so the API key cannot be bypassed
  void api.watchlist.items.list;
});

test("save, edit, list, device and inbox work through HTTP, and bad input is a 400", async () => {
  vi.stubEnv("APP_API_KEY", KEY);
  const t = convexTest(schema, modules);
  const productId = await product(t);
  expect((await call(t, "/watchlist/save", { method: "POST", body: { deviceId: D, productId, targetPrice: 99 } })).status).toBe(200);
  expect((await call(t, "/watchlist/save", { method: "POST", body: { deviceId: D, productId, prefs: { new_low: false } } })).status).toBe(200);
  const list = await (await call(t, "/watchlist?deviceId=" + D)).json();
  expect(list).toHaveLength(1);
  expect(list[0]).toMatchObject({ targetPrice: 99, prefs: { new_low: false, target_hit: true } });

  expect((await call(t, "/watchlist/save", { method: "POST", body: { deviceId: D, productId, prefs: { nope: true } } })).status).toBe(400);
  expect((await call(t, "/watchlist/device", { method: "POST", body: { deviceId: D, environment: "prod" } })).status).toBe(400);
  expect((await call(t, "/watchlist/device", { method: "POST", body: { deviceId: D, environment: "sandbox", apnsToken: "ab".repeat(32) } })).status).toBe(200);
  expect((await call(t, "/watchlist/device", { method: "POST", body: { deviceId: D } })).status).toBe(200);
  expect((await t.run((ctx) => ctx.db.query("devices").collect()))[0].apnsToken).toBe("ab".repeat(32));
  expect(await (await call(t, "/watchlist/notifications?deviceId=" + D)).json()).toEqual([]);
  expect((await call(t, "/watchlist", { method: "GET" })).status).toBe(400);
});

test("a device is rate limited after its window quota, other devices are not", async () => {
  vi.stubEnv("APP_API_KEY", KEY);
  const t = convexTest(schema, modules);
  for (let i = 0; i < RATE_LIMIT.limit; i++) expect((await call(t, "/watchlist?deviceId=" + D)).status).toBe(200);
  expect((await call(t, "/watchlist?deviceId=" + D)).status).toBe(429);
  expect((await call(t, "/watchlist?deviceId=device-other-0002")).status).toBe(200);
  vi.advanceTimersByTime(RATE_LIMIT.windowMs + 1);
  expect((await call(t, "/watchlist?deviceId=" + D)).status).toBe(200);
});
