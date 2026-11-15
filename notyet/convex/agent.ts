import { v } from "convex/values";
import { internalAction, type ActionCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { callOpenAI, parseJSON, WEB_SEARCH } from "./openai";
import { waybackHistory } from "./wayback";
import { decide, mergeHistory, pickStore, type Listing, type PricePoint } from "./verdict";

type Identified = {
  name: string;
  brand?: string | null;
  model?: string | null;
  variant?: string | null;
  visiblePrice?: number | null;
  wasPrice?: number | null;
  retailer?: string | null;
  confidence: number;
};
type QuickSearch = { listings: Listing[]; recentLow?: number | null; typicalPrice?: number | null };
type QuickPublic = { productName: string; verdict: string; oneLiner: string; retailer?: string | null };

const CACHE_MS = 24 * 60 * 60 * 1000;

export const productKey = (p: Identified) =>
  `${p.brand ?? ""} ${p.model || p.name} ${p.variant ?? ""}`.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();

const describe = (p: Identified) => [p.brand, p.name, p.model, p.variant].filter(Boolean).join(" ");

async function identify(imageUrl: string): Promise<Identified> {
  const text = await callOpenAI({
    fast: true,
    input: [
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text:
              "You identify the main product in a phone screenshot. Return ONLY JSON: " +
              '{"name": string, "brand": string|null, "model": exact model number or most specific identifier|null, ' +
              '"variant": size/color/storage if visible|null, "visiblePrice": current price shown as a number|null, ' +
              '"wasPrice": crossed-out or "was"/list price shown as a number|null, "retailer": store shown|null, ' +
              '"confidence": 0 to 1}. If no product is visible, set confidence to 0.',
          },
          { type: "input_image", image_url: imageUrl },
        ],
      },
    ],
  });
  return parseJSON<Identified>(text);
}

async function identifyText(q: string): Promise<Identified> {
  const text = await callOpenAI({
    fast: true,
    input:
      `A shopper typed: "${q}". Work out the single product they mean. Return ONLY JSON: ` +
      '{"name": string, "brand": string|null, "model": exact model number or most specific identifier|null, ' +
      '"variant": string|null, "visiblePrice": price they mentioned as a number|null, "wasPrice": null, ' +
      '"retailer": store they mentioned|null, "confidence": 0 to 1}. If no specific product, set confidence to 0.',
  });
  return parseJSON<Identified>(text);
}

export async function quickSearch(p: Identified): Promise<QuickSearch> {
  const text = await callOpenAI({
    fast: true,
    tools: WEB_SEARCH,
    input:
      `Find the current price of this exact product at major US retailers right now: ${describe(p)}. ` +
      "Return ONLY JSON: " +
      '{"listings": [{"retailer": string, "price": number, "url": direct product page URL, "shipping": number, ' +
      '"seller": "retailer" or "third-party", "inStock": boolean, ' +
      '"rating": average star rating out of 5|null, "reviewCount": number of reviews|null}], ' +
      '"recentLow": lowest price you can find for it in the last 12 months|null, ' +
      '"typicalPrice": its usual non-sale price|null}. At most 5 listings.',
  });
  const qs = parseJSON<QuickSearch>(text);
  qs.listings = (qs.listings ?? [])
    .map((l) => ({
      ...l,
      price: Number(l.price),
      shipping: Number(l.shipping ?? 0),
      rating: l.rating != null ? Number(l.rating) : null,
      reviewCount: l.reviewCount != null ? Math.round(Number(l.reviewCount)) : null,
    }))
    .filter((l) => l.price > 0 && typeof l.url === "string");
  return qs;
}

function quickVerdict(p: Identified, qs: QuickSearch): QuickPublic {
  const retailer = pickStore(qs.listings)?.retailer ?? p.retailer ?? null;
  return { ...quickVerdictCore(p, qs), retailer };
}

function quickVerdictCore(p: Identified, qs: QuickSearch): QuickPublic {
  const cheapest = qs.listings.length ? Math.min(...qs.listings.map((l) => l.price)) : null;
  const current = p.visiblePrice ?? cheapest ?? 0;
  const name = p.name;
  if (p.wasPrice && qs.typicalPrice && p.wasPrice > qs.typicalPrice * 1.15)
    return { productName: name, verdict: "FAKE_DEAL", oneLiner: `Fake deal. It's usually ~$${Math.round(qs.typicalPrice)} anyway.` };
  if (qs.recentLow && current && current <= qs.recentLow * 1.03)
    return { productName: name, verdict: "BUY_NOW", oneLiner: `Buy now. $${Math.round(current)} is about its lowest this year.` };
  if (qs.recentLow && current && current > qs.recentLow * 1.08)
    return { productName: name, verdict: "WAIT", oneLiner: `Wait. It's been $${Math.round(qs.recentLow)} recently.` };
  return { productName: name, verdict: "BUY_NOW", oneLiner: current ? `Fair price at $${Math.round(current)}. Checking history…` : "Checking prices…" };
}

// Runs inside the POST /scan and POST /ask HTTP actions so the caller gets a verdict in one round trip.
export async function runQuickPass(
  ctx: ActionCtx,
  scanId: Id<"scans">,
  input: { imageId: Id<"_storage"> } | { query: string },
): Promise<QuickPublic> {
  const patch = (fields: Record<string, unknown>) => ctx.runMutation(internal.scans.patch, { id: scanId, fields });

  let p: Identified;
  if ("imageId" in input) {
    const imageUrl = await ctx.storage.getUrl(input.imageId);
    if (!imageUrl) throw new Error("Image missing from storage");
    p = await identify(imageUrl);
  } else {
    p = await identifyText(input.query);
  }

  if (!p.confidence || p.confidence < 0.3) {
    await patch({ status: "error", error: "No product found", step: "No product found" });
    return {
      productName: "No product found",
      verdict: "NONE",
      oneLiner: "Couldn't spot a product. Try the product page, or name the exact model.",
    };
  }

  const key = productKey(p);
  const cached = await ctx.runQuery(internal.products.get, { key });
  if (cached && Date.now() - cached.updatedAt < CACHE_MS) {
    const pub = {
      productName: cached.result.product.name,
      verdict: cached.result.verdict,
      oneLiner: cached.result.oneLiner,
      retailer: cached.result.whereToBuy?.retailer ?? null,
    };
    await patch({ status: "done", step: "Done", productKey: key, quick: { identified: p, public: pub }, result: cached.result });
    return pub;
  }

  await patch({ step: "Checking prices…", productKey: key });
  const qs = await quickSearch(p);
  const pub = quickVerdict(p, qs);
  await patch({ status: "deep", step: "Reading the price history…", quick: { identified: p, ...qs, public: pub } });
  await ctx.scheduler.runAfter(0, internal.agent.deepPass, { scanId });
  return pub;
}

async function dealPostHistory(p: Identified): Promise<PricePoint[]> {
  try {
    const text = await callOpenAI({
      tools: WEB_SEARCH,
      input:
        `Find dated historical sale prices for ${describe(p)} at US retailers over the last 24 months. ` +
        "Use deal sites (like Slickdeals or 9to5Toys), price trackers and news posts. " +
        "Only include prices you actually found with a date. Return ONLY JSON: " +
        '{"points": [{"date": "YYYY-MM-DD", "price": number, "retailer": string, "sourceUrl": string}]}. At most 25 points.',
    });
    const { points } = parseJSON<{ points: { date: string; price: number; retailer: string }[] }>(text);
    return (points ?? []).map((x) => ({ date: x.date, price: Number(x.price), retailer: x.retailer, source: "deal_post" }));
  } catch {
    return [];
  }
}

export const deepPass = internalAction({
  args: { scanId: v.id("scans") },
  handler: async (ctx, { scanId }) => {
    const patch = (fields: Record<string, unknown>) => ctx.runMutation(internal.scans.patch, { id: scanId, fields });
    try {
      const scan = await ctx.runQuery(internal.scans.get, { id: scanId });
      if (!scan?.quick) throw new Error("Quick pass missing");
      const p: Identified = scan.quick.identified;
      const listings: Listing[] = scan.quick.listings ?? [];

      // Rebuild price history: archived pages for the top listings, plus dated deal posts.
      const [archived, posts] = await Promise.all([
        Promise.all(listings.slice(0, 3).map((l) => waybackHistory(l.url, l.retailer))).then((r) => r.flat()),
        dealPostHistory(p),
      ]);
      const history = mergeHistory([...archived, ...posts]);

      await patch({ step: "Picking the best time and store…" });
      const store = pickStore(listings);
      const current = store?.price ?? p.visiblePrice ?? (history.length ? history[history.length - 1].price : 0);
      const vd = decide({ history, current, wasPrice: p.wasPrice, needBy: scan.needBy });

      // The model only writes copy from numbers we computed.
      const facts = { product: describe(p), current, verdict: vd.verdict, expectedPrice: vd.expectedPrice, waitUntil: vd.waitUntil, reasons: vd.reasons, store: store ? { retailer: store.retailer, totalCost: store.totalCost, thirdPartyAlternativesSkipped: listings.some((l) => /third/i.test(l.seller ?? "")) } : null };
      const copy = parseJSON<{ oneLiner: string; tldr: string; storeReason: string }>(
        await callOpenAI({
          fast: true,
          input:
            "You write copy for a shopping app. Using ONLY these facts, return ONLY JSON: " +
            '{"oneLiner": max 12 words, starting with "Buy now.", "Wait." or "Fake deal.", ' +
            '"tldr": 2 or 3 short sentences on what to do, when, where and why, citing a specific past price or sale, ' +
            '"storeReason": one short sentence on why this store}. Facts: ' + JSON.stringify(facts),
        }),
      );

      // Extra numbers for the report screen.
      const rated = listings.filter((l) => typeof l.rating === "number" && (l.rating ?? 0) > 0);
      const weight = (l: Listing) => Math.max(1, l.reviewCount ?? 1);
      const avgRating = rated.length
        ? Math.round((rated.reduce((a, l) => a + (l.rating ?? 0) * weight(l), 0) / rated.reduce((a, l) => a + weight(l), 0)) * 10) / 10
        : null;
      const reviewCount = rated.reduce((a, l) => a + (l.reviewCount ?? 0), 0) || null;
      const spanDays = history.length >= 2
        ? (Date.parse(history[history.length - 1].date) - Date.parse(history[0].date)) / 86_400_000
        : 0;
      const projectedPrice = vd.expectedPrice
        ? Math.round((vd.expectedPrice.low + vd.expectedPrice.high) / 2)
        : Math.round(Number.isFinite(vd.stats.median) ? vd.stats.median : current);

      const result = {
        projectedPrice,
        sourcesChecked: listings.length + archived.length + posts.length,
        yearsOfData: Math.round((spanDays / 365) * 10) / 10,
        avgRating,
        reviewCount,
        product: { name: p.name, brand: p.brand ?? null, model: p.model ?? null },
        verdict: vd.verdict,
        oneLiner: copy.oneLiner,
        confidence: Math.round(vd.confidence * 100) / 100,
        currentPrice: current,
        expectedPrice: vd.expectedPrice,
        waitUntil: vd.waitUntil,
        whereToBuy: store ? { retailer: store.retailer, price: store.price, totalCost: store.totalCost, url: store.url, reason: copy.storeReason } : null,
        history,
        tldr: copy.tldr,
        stats: vd.stats,
        reasons: vd.reasons,
      };
      await patch({ status: "done", step: "Done", result });
      if (scan.productKey) await ctx.runMutation(internal.products.upsert, { key: scan.productKey, name: p.name, result });
    } catch (e) {
      await patch({ status: "error", error: String(e), step: "Something went wrong" });
    }
  },
});

// Daily: re-check every saved item that's still inside its need-by window.
export const recheckSaved = internalAction({
  args: {},
  handler: async (ctx) => {
    const items = await ctx.runQuery(internal.wishlist.listActive, {});
    for (const it of items) {
      try {
        const scan = await ctx.runQuery(internal.scans.byKey, { scanKey: it.scanKey });
        const p: Identified | undefined = scan?.quick?.identified;
        if (!p) continue;
        const store = pickStore((await quickSearch(p)).listings);
        if (store) await ctx.runMutation(internal.wishlist.recordCheck, { id: it._id, price: store.price, retailer: store.retailer });
      } catch {
        // one bad item shouldn't stop the rest
      }
    }
  },
});
