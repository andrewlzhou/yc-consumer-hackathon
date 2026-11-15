// Deterministic history generator: the same tracks always give the same points.

export const SEED_NOW = Date.UTC(2026, 10, 15, 18, 0);
const DAY = 24 * 60 * 60 * 1000;

// A retailer's price story for one product.
// regular: step function of [fromDate, price]. sales: [start, end, price, shownWas?] (was defaults to regular).
// points: explicit observations [date, price | null (out of stock), shownWas?] that replace sampled ones that day.
export type Track = {
  retailer: string;
  from?: string;
  regular: [string, number][];
  sales?: [string, string, number, number?][];
  outOfStock?: [string, string][];
  points?: [string, number | null, number?][];
  jitter?: number;
  everyDays?: number;
};

export type SeedPoint = {
  retailerSlug: string;
  price?: number;
  originalPrice?: number;
  inStock: boolean;
  observedAt: number;
};

const day = (iso: string) => Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10), 17, 0);

// mulberry32 seeded from a string hash.
function rng(seed: string) {
  let h = 1779033703 ^ seed.length;
  for (let i = 0; i < seed.length; i++) h = Math.imul(h ^ seed.charCodeAt(i), 3432918353);
  let a = (h << 13) | (h >>> 19);
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const inRange = (t: number, [a, b]: [string, string]) => t >= day(a) && t <= day(b);

export function generateTrack(track: Track, seedKey: string, now = SEED_NOW): SeedPoint[] {
  const random = rng(seedKey + ":" + track.retailer);
  const explicit = new Map((track.points ?? []).map(([d, price, was]) => [day(d), { price, was }]));
  const out: SeedPoint[] = [];
  const start = day(track.from ?? track.regular[0]?.[0] ?? "2026-11-15");
  const every = track.everyDays ?? 3;
  for (let t = start; t <= now && track.regular.length; t += DAY) {
    if (explicit.has(t)) continue;
    const sale = (track.sales ?? []).find(([a, b]) => inRange(t, [a, b]));
    const recent = now - t < 10 * DAY;
    const offset = Math.round((t - start) / DAY);
    if (!sale && !recent && offset % every !== 0) continue;
    const regular = [...track.regular].reverse().find(([d]) => day(d) <= t)?.[1];
    if (regular === undefined) continue;
    if ((track.outOfStock ?? []).some((r) => inRange(t, r))) {
      out.push({ retailerSlug: track.retailer, inStock: false, observedAt: t });
      continue;
    }
    let price = sale ? sale[2] : regular;
    if (!sale && track.jitter && random() < 0.15) {
      const k = 1 + Math.floor(random() * track.jitter);
      price = Math.max(1, price - k);
    }
    const shownWas = sale ? (sale[3] ?? regular) : undefined;
    out.push({
      retailerSlug: track.retailer,
      price,
      originalPrice: shownWas !== undefined && shownWas > price ? shownWas : undefined,
      inStock: true,
      observedAt: t,
    });
  }
  for (const [t, { price, was }] of explicit) {
    if (t > now) continue;
    out.push({
      retailerSlug: track.retailer,
      price: price ?? undefined,
      originalPrice: price !== null && was !== undefined && was > price ? was : undefined,
      inStock: price !== null,
      observedAt: t,
    });
  }
  return out.sort((a, b) => a.observedAt - b.observedAt);
}
