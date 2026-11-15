// Pure math. No model calls in here: code decides, the model only explains.

export type PricePoint = { date: string; price: number; retailer?: string; source: string };
export type Listing = {
  retailer: string;
  price: number;
  url: string;
  shipping?: number;
  seller?: string; // "retailer" | "third-party"
  inStock?: boolean;
  rating?: number | null; // average stars, 0 to 5
  reviewCount?: number | null;
};
export type VerdictKind = "BUY_NOW" | "WAIT" | "FAKE_DEAL";

const DAY = 86_400_000;
const toTime = (d: string) => new Date(d + "T12:00:00Z").getTime();
export const addDays = (d: string, n: number) => new Date(toTime(d) + n * DAY).toISOString().slice(0, 10);
const round = (x: number) => Math.round(x);

// Past sale windows we look for in each product's own history.
const PAST_EVENTS = [
  { family: "Prime Day", start: "2024-07-16", end: "2024-07-17" },
  { family: "Prime Day", start: "2025-07-08", end: "2025-07-11" },
  { family: "Fall Prime", start: "2024-10-08", end: "2024-10-09" },
  { family: "Fall Prime", start: "2025-10-07", end: "2025-10-08" },
  { family: "BFCM", start: "2024-11-22", end: "2024-12-03" },
  { family: "BFCM", start: "2025-11-21", end: "2025-12-02" },
  { family: "After-Christmas", start: "2024-12-26", end: "2024-12-31" },
  { family: "After-Christmas", start: "2025-12-26", end: "2025-12-31" },
  { family: "Presidents' Day", start: "2025-02-14", end: "2025-02-17" },
  { family: "Presidents' Day", start: "2026-02-13", end: "2026-02-16" },
];

// Upcoming events a "wait" verdict can point to.
const UPCOMING = [
  { name: "Black Friday", date: "2026-11-27", family: "BFCM" },
  { name: "Cyber Monday", date: "2026-11-30", family: "BFCM" },
  { name: "after-Christmas sales", date: "2026-12-26", family: "After-Christmas" },
  { name: "Presidents' Day sales", date: "2027-02-15", family: "Presidents' Day" },
];

function median(xs: number[]): number {
  if (!xs.length) return NaN;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

function quantile(xs: number[], q: number): number {
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.max(0, Math.round(q * (s.length - 1))))];
}

export function mergeHistory(points: PricePoint[]): PricePoint[] {
  const clean = points.filter(
    (p) => p && Number.isFinite(p.price) && p.price > 0 && /^\d{4}-\d{2}-\d{2}$/.test(p.date),
  );
  if (!clean.length) return [];
  const med = median(clean.map((p) => p.price));
  const seen = new Set<string>();
  return clean
    .filter((p) => p.price > med * 0.3 && p.price < med * 3) // drop parse garbage
    .filter((p) => {
      const k = `${p.date}|${p.retailer ?? ""}|${p.price}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    })
    .sort((a, b) => a.date.localeCompare(b.date));
}

export function computeStats(history: PricePoint[], current: number) {
  const prices = history.map((h) => h.price);
  if (!prices.length) return { n: 0, allTimeLow: current, median: current, p90: current, percentile: 0.5 };
  return {
    n: prices.length,
    allTimeLow: Math.min(...prices),
    median: median(prices),
    p90: quantile(prices, 0.9),
    percentile: prices.filter((p) => p < current).length / prices.length,
  };
}

// How much did this product drop during past events of this family, vs the 60 days before?
function eventDrops(history: PricePoint[], family: string): number[] {
  const drops: number[] = [];
  for (const e of PAST_EVENTS.filter((x) => x.family === family)) {
    const s = toTime(e.start) - 2 * DAY;
    const en = toTime(e.end) + 2 * DAY;
    const inside = history.filter((p) => toTime(p.date) >= s && toTime(p.date) <= en).map((p) => p.price);
    const before = history
      .filter((p) => toTime(p.date) < s && toTime(p.date) >= s - 60 * DAY)
      .map((p) => p.price);
    if (inside.length && before.length) {
      const d = 1 - Math.min(...inside) / median(before);
      if (d > 0) drops.push(d);
    }
  }
  return drops;
}

export function decide(args: {
  history: PricePoint[];
  current: number;
  wasPrice?: number | null;
  needBy?: string;
  today?: string;
}) {
  const today = args.today ?? new Date().toISOString().slice(0, 10);
  const deadline = args.needBy ?? addDays(today, 75);
  const { history, current } = args;
  const s = computeStats(history, current);
  const reasons: string[] = [];
  const baseConf = Math.min(0.9, 0.35 + s.n * 0.03);
  const base = { stats: s, reasons };

  // 1. Fake deal: the "was" price barely ever existed, and today's price is ordinary.
  if (args.wasPrice && s.n >= 4 && args.wasPrice > s.p90 * 1.02 && current >= s.median * 0.97) {
    reasons.push(
      `The "was" price of $${round(args.wasPrice)} is above nearly every price on record (90% of prices were $${round(s.p90)} or less).`,
      `Today's $${round(current)} is about its typical price of $${round(s.median)}.`,
    );
    return { ...base, verdict: "FAKE_DEAL" as VerdictKind, confidence: baseConf, expectedPrice: null, waitUntil: null };
  }

  // 2. Buy now: within 3% of the lowest price on record.
  if (s.n >= 3 && current <= s.allTimeLow * 1.03) {
    reasons.push(`$${round(current)} is within 3% of the lowest price on record ($${round(s.allTimeLow)}).`);
    return { ...base, verdict: "BUY_NOW" as VerdictKind, confidence: baseConf, expectedPrice: null, waitUntil: null };
  }

  // 3. Wait: a sale event lands before the deadline and this product dropped 8%+ in past ones.
  let best: { name: string; date: string; drop: number; count: number } | null = null;
  for (const u of UPCOMING) {
    if (u.date <= today || u.date > deadline) continue;
    const drops = eventDrops(history, u.family);
    if (!drops.length) continue;
    const avg = drops.reduce((a, b) => a + b, 0) / drops.length;
    if (avg >= 0.08 && (!best || avg > best.drop)) best = { name: u.name, date: u.date, drop: avg, count: drops.length };
  }
  if (best) {
    const exp = current * (1 - best.drop);
    const high = round(exp * 1.03);
    const low = Math.min(high, round(Math.max(s.allTimeLow, exp * 0.97)));
    reasons.push(
      `It dropped about ${round(best.drop * 100)}% in ${best.count} past sale${best.count > 1 ? "s" : ""} like ${best.name}.`,
      `${best.name} is on ${best.date}, before your need-by date.`,
    );
    return {
      ...base,
      verdict: "WAIT" as VerdictKind,
      confidence: Math.min(0.92, baseConf + 0.1 * best.count),
      expectedPrice: { low, high },
      waitUntil: best.date,
    };
  }

  // 4. Weaker wait: priced well above its usual level.
  if (s.n >= 3 && current > s.median * 1.08) {
    const next = UPCOMING.find((u) => u.date > today && u.date <= deadline);
    reasons.push(`$${round(current)} is above its typical price of $${round(s.median)}.`);
    return {
      ...base,
      verdict: "WAIT" as VerdictKind,
      confidence: baseConf * 0.8,
      expectedPrice: { low: round(s.allTimeLow), high: round(s.median) },
      waitUntil: next?.date ?? addDays(today, 30),
    };
  }

  reasons.push(
    s.n
      ? `$${round(current)} is a normal price for this item (typical $${round(s.median)}).`
      : "Not much price history yet, so this is a low-confidence call.",
  );
  return { ...base, verdict: "BUY_NOW" as VerdictKind, confidence: baseConf * 0.7, expectedPrice: null, waitUntil: null };
}

const TRUSTED = ["amazon", "best buy", "target", "walmart", "costco", "apple", "b&h", "nike", "nordstrom", "home depot", "lowe"];

export function pickStore(listings: Listing[]) {
  const scored = listings
    .filter((l) => l.price > 0 && l.inStock !== false)
    .map((l) => {
      const totalCost = l.price + (l.shipping ?? 0);
      const thirdParty = /third/i.test(l.seller ?? "");
      const trusted = TRUSTED.some((t) => l.retailer.toLowerCase().includes(t));
      // Small penalties: a few dollars saved isn't worth a sketchy seller.
      const score = totalCost * (thirdParty ? 1.06 : 1) * (trusted ? 1 : 1.03);
      return { ...l, totalCost, thirdParty, trusted, score };
    })
    .sort((a, b) => a.score - b.score);
  return scored[0] ?? null;
}
