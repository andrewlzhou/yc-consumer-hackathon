import { median, priced, round2, trustedPoints, type PricePoint } from "../data/stats";

type Event = { name: string; startsAt: number; endsAt: number; retailerSlug?: string };
const day = (ms: number) => new Date(ms).toISOString().slice(0, 10);

// Chart-ready price history: one step series per retailer (a point only on days the price changed, plus the latest),
// sale events for shading, and where the points come from. Uses the same trusted points as the stats.
export function chartData(points: PricePoint[], events: Event[]) {
  const trusted = priced(trustedPoints(points)).sort((a, b) => a.observedAt - b.observedAt);
  const retailers = [...new Set(trusted.map((p) => p.retailerSlug))].sort();
  const series = retailers.map((retailer) => {
    const daily = new Map<string, (typeof trusted)[number]>();
    for (const p of trusted.filter((x) => x.retailerSlug === retailer)) daily.set(day(p.observedAt), p);
    const days = [...daily.entries()];
    const steps = days.filter(([, p], i) => i === 0 || i === days.length - 1 || p.price !== days[i - 1][1].price);
    const prices = days.map(([, p]) => p.price);
    return {
      retailer,
      points: steps.map(([date, p]) => ({ date, price: p.price, source: p.source })),
      lowest: Math.min(...prices),
      latest: prices[prices.length - 1],
    };
  });
  const all = trusted.map((p) => p.price);
  const sources: Record<string, number> = {};
  for (const p of trusted) sources[p.source] = (sources[p.source] ?? 0) + 1;
  const low = trusted.find((p) => p.price === Math.min(...all));
  return {
    kind: "step" as const,
    from: trusted.length ? day(trusted[0].observedAt) : null,
    to: trusted.length ? day(trusted[trusted.length - 1].observedAt) : null,
    series,
    lowest: low ? { price: low.price, date: day(low.observedAt), retailer: low.retailerSlug } : null,
    typicalPrice: all.length ? round2(median(all)) : null,
    events: events.map((e) => ({ name: e.name, startsAt: day(e.startsAt), endsAt: day(e.endsAt), retailer: e.retailerSlug ?? null })),
    sources,
    isSampleData: trusted.some((p) => p.source === "seed"),
  };
}
