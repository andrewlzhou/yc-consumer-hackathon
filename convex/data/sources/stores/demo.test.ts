import { convexTest } from "convex-test";
import { afterEach, expect, test, vi } from "vitest";
import { internal } from "../../../_generated/api";
import schema from "../../../schema";
import { SEED_NOW } from "../../../seed/generate";
import { modules } from "../../../test.setup";
import ae from "./fixtures/google-ae-baggy.json";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.useRealTimers();
});

test("the real AE response ingests a year of changes without mixing the archived colorway", async () => {
  const t = convexTest(schema, modules);
  vi.stubEnv("SERPAPI_API_KEY", "test-key");
  vi.stubEnv("OPENAI_API_KEY", "");
  vi.useFakeTimers({ now: SEED_NOW, toFake: ["Date"] });
  const fetchMock = vi.fn(async () => new Response(JSON.stringify(ae)));
  vi.stubGlobal("fetch", fetchMock);
  const result = await t.action(internal.data.demo.ingest, { key: "ae-baggy-jean" });
  expect(result.wayback).toEqual([]);
  expect(fetchMock).toHaveBeenCalledTimes(1);
  expect(result.serpapi.status).toBe("ok");
  const stats = await t.query(internal.data.prices.getPriceStats, {
    productId: result.productId, now: SEED_NOW, windowDays: 365, retailerSlug: "ae", currentPrice: 35.97, originalPrice: 59.95,
  });
  expect(stats.isSampleData).toBe(false);
  expect(stats.overall.prices).toMatchObject({ min: 29.97, max: 59.95 });
  expect(stats.wasPrice!.shareChargedAtOrAbove).toBeGreaterThan(0);
  expect(stats.wasPrice!.shareChargedAtOrAbove).toBeLessThan(0.2);
  const product = await t.query(internal.data.catalog.getProduct, { productId: result.productId });
  expect(product?.variant).toEqual({ color: "Black", size: "33 X 32" });
});
