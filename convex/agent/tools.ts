import type { AgentTool } from "./loop";
import type { JsonSchema } from "./llm";
import type { DataPort } from "./port";

const nullableNum = { type: ["number", "null"] };
const nullableStr = { type: ["string", "null"] };
const params = (properties: Record<string, unknown>): JsonSchema => ({ type: "object", properties, required: Object.keys(properties), additionalProperties: false });

const str = (value: unknown, name: string): string => {
  if (typeof value !== "string" || !value) throw new Error(`${name} must be a non-empty string`);
  return value;
};
const num = (value: unknown) => (typeof value === "number" && Number.isFinite(value) ? value : undefined);
const opt = (value: unknown) => (typeof value === "string" && value ? value : undefined);
const round2 = (n: number) => Math.round(n * 100) / 100;

// Exact arithmetic for the model, so derived numbers in its text come from a tool result too.
export function calculate(operation: string, a: number, b: number): number {
  if (operation === "difference") return round2(a - b);
  if (operation === "percent_change") return round2(((a - b) / b) * 100);
  if (operation === "percent_of") return round2((a / b) * 100);
  if (operation === "sum") return round2(a + b);
  throw new Error(`unknown operation ${operation}`);
}

export const COMPETITOR_TOOLS = ["find_competitors", "compare_products", "insights"];

export function buildTools(data: DataPort): AgentTool[] {
  return [
    {
      name: "search_catalog",
      description: "Search our catalog by title. Returns scored candidates (score 0-1, sizeConflict when storage/size differs).",
      parameters: params({ query: { type: "string" } }),
      run: (a) => data.searchCatalog(str(a.query, "query")),
    },
    {
      name: "get_price_stats",
      description: "Exact price stats over a window: overall and per retailer (median, mean, min, max, percentiles, span, latest) and where the current price sits. Pass the scanned price and claimed was-price to get a was-price check (how often it was really charged, claimed vs real discount). Percent fields are already percents.",
      parameters: params({ productId: { type: "string" }, retailer: nullableStr, days: nullableNum, currentPrice: nullableNum, originalPrice: nullableNum }),
      run: (a) => data.stats(str(a.productId, "productId"), { retailer: opt(a.retailer), days: num(a.days), currentPrice: num(a.currentPrice), originalPrice: num(a.originalPrice) }),
    },
    {
      name: "get_price_history",
      description: "Observed price points (date, retailer, price, was-price, source), oldest first, evenly sampled to at most 60 points.",
      parameters: params({ productId: { type: "string" }, retailer: nullableStr, days: nullableNum }),
      run: (a) => data.history(str(a.productId, "productId"), opt(a.retailer), Math.min(num(a.days) ?? 180, 400)),
    },
    {
      name: "get_promo_patterns",
      description: "Past sale episodes (depth, matched calendar events, pre-sale hikes), claimed discounts with how often the was-price was charged before, recurrence, and upcoming events with this product's past sale prices at the same event.",
      parameters: params({ productId: { type: "string" }, retailer: nullableStr }),
      run: (a) => data.promo(str(a.productId, "productId"), opt(a.retailer)),
    },
    {
      name: "get_sale_calendar",
      description: "Sale events (national and retailer) from today through the next N days.",
      parameters: params({ days: nullableNum }),
      run: (a) => data.calendar(Math.min(num(a.days) ?? 45, 120)),
    },
    {
      name: "get_price_digest",
      description: "A short precomputed text summary of the product's price history.",
      parameters: params({ productId: { type: "string" } }),
      run: (a) => data.digest(str(a.productId, "productId")),
    },
    {
      name: "find_competitors",
      description: "Same-category products from other model families with specs and 90-day price summaries. The only valid source of competitors; you judge which are truly comparable.",
      parameters: params({ productId: { type: "string" } }),
      run: (a) => data.comparables(str(a.productId, "productId")),
    },
    {
      name: "compare_products",
      description: "Two catalog products side by side: specs, 90-day median and latest prices, and exact price differences.",
      parameters: params({ productId: { type: "string" }, otherProductId: { type: "string" } }),
      run: async (a) => {
        const [ida, idb] = [str(a.productId, "productId"), str(a.otherProductId, "otherProductId")];
        const [pa, pb] = await Promise.all([data.product(ida), data.product(idb)]);
        if (!pa || !pb) throw new Error("unknown productId");
        const [sa, sb] = (await Promise.all([data.stats(ida, { days: 90 }), data.stats(idb, { days: 90 })])) as { overall: { prices: { median: number; latest: { price: number } } | null } }[];
        const latestA = sa.overall.prices?.latest.price ?? null;
        const latestB = sb.overall.prices?.latest.price ?? null;
        return {
          product: { productId: ida, title: pa.title, specs: pa.specs, median90: sa.overall.prices?.median ?? null, latestPrice: latestA },
          other: { productId: idb, title: pb.title, specs: pb.specs, median90: sb.overall.prices?.median ?? null, latestPrice: latestB },
          otherMinusProductLatest: latestA !== null && latestB !== null ? calculate("difference", latestB, latestA) : null,
          otherVsProductLatestPercent: latestA !== null && latestB !== null ? calculate("percent_change", latestB, latestA) : null,
        };
      },
    },
    {
      name: "calculate",
      description: "Exact arithmetic. difference = a - b; percent_change = (a - b) / b * 100; percent_of = a / b * 100; sum = a + b. Rounded to cents.",
      parameters: params({ operation: { type: "string", enum: ["difference", "percent_change", "percent_of", "sum"] }, a: { type: "number" }, b: { type: "number" } }),
      run: async (a) => ({ operation: a.operation, a: a.a, b: a.b, result: calculate(str(a.operation, "operation"), Number(a.a), Number(a.b)) }),
    },
  ];
}
