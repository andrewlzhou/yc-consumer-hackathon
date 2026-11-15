import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import schema from "../schema";
import { modules } from "../test.setup";
import { tokenize } from "./text";

// Deterministic stand-in for OpenAI embeddings: hashed bag of tokens, unit length.
function fakeEmbedding(text: string) {
  const vec = new Array(1536).fill(0);
  for (const tok of tokenize(text)) {
    let h = 0;
    for (const ch of tok) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
    vec[h % 1536] += 1;
  }
  const norm = Math.sqrt(vec.reduce((s, x) => s + x * x, 0)) || 1;
  return vec.map((x) => x / norm);
}

let t: ReturnType<typeof convexTest>;
let ids: Record<string, Id<"products">>;

beforeEach(async () => {
  t = convexTest(schema, modules);
  ids = (await t.action(internal.seed.run.all, {})).products as Record<string, Id<"products">>;
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

function stubOpenAI() {
  vi.stubGlobal("fetch", vi.fn(async (_url: string, init: { body: string }) => {
    const input = JSON.parse(init.body).input as string[];
    return new Response(JSON.stringify({ data: input.map((s, index) => ({ index, embedding: fakeEmbedding(s) })) }), { status: 200 });
  }));
}

test("without a key, matching falls back to text-only", async () => {
  vi.stubEnv("OPENAI_API_KEY", "");
  const r = await t.action(internal.data.embeddings.hybridMatch, { title: "Apple AirPods Pro 3" });
  expect(r.mode).toBe("text");
  expect(r.candidates[0].product.familyKey).toBe("apple-airpods-pro-3");
  expect((await t.action(internal.data.embeddings.embedCatalog, {})).status).toBe("no_key");
});

test("embeds the catalog once and fuses text and vector hits", async () => {
  vi.stubEnv("OPENAI_API_KEY", "test-key");
  stubOpenAI();
  expect(await t.action(internal.data.embeddings.embedCatalog, {})).toEqual({ status: "ok", embedded: 8 });
  expect(await t.action(internal.data.embeddings.embedCatalog, {})).toEqual({ status: "ok", embedded: 0 });
  const r = await t.action(internal.data.embeddings.hybridMatch, { title: "Apple 11-inch iPad A16 Wi-Fi 256 GB - Silver" });
  expect(r.mode).toBe("hybrid");
  expect(r.candidates[0].product.variant).toEqual({ storage: "256GB" });
  expect(r.candidates[0].vectorScore).not.toBeNull();
  expect(JSON.stringify(r)).not.toContain("embedding");
});

test("similar products stay in the category and skip the same family", async () => {
  vi.stubEnv("OPENAI_API_KEY", "test-key");
  stubOpenAI();
  await t.action(internal.data.embeddings.embedCatalog, {});
  const r = await t.action(internal.data.embeddings.findSimilarProducts, { productId: ids["bose-qcu-2"] });
  expect(r.mode).toBe("vector");
  expect(r.products.map((p) => p.product.familyKey).sort()).toEqual(["sony-wh-1000xm5", "sony-wh-1000xm6"]);
});

test("vectors live in their own table and the backfill pages past the first page", async () => {
  vi.stubEnv("OPENAI_API_KEY", "test-key");
  stubOpenAI();
  await t.run(async (ctx) => {
    for (let i = 0; i < 130; i++) {
      await ctx.db.insert("products", {
        title: `Filler Gadget ${i}`, brand: "Acme", category: "gadgets", familyKey: `filler-${i}`, specs: {}, aliases: [],
        searchText: `filler gadget ${i}`, isSample: false, provisional: false,
      });
    }
  });
  expect(await t.action(internal.data.embeddings.embedCatalog, {})).toEqual({ status: "ok", embedded: 138 });
  const counts = await t.run(async (ctx) => ({
    embeddings: (await ctx.db.query("productEmbeddings").collect()).length,
    inline: (await ctx.db.query("products").collect()).filter((p) => "embedding" in p).length,
  }));
  expect(counts).toEqual({ embeddings: 138, inline: 0 });
  expect(await t.action(internal.data.embeddings.embedCatalog, {})).toEqual({ status: "ok", embedded: 0 });
});
