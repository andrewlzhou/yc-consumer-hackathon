import type { PricePoint } from "./verdict";

async function fetchWithTimeout(url: string, ms: number): Promise<Response> {
  const c = new AbortController();
  const t = setTimeout(() => c.abort(), ms);
  try {
    return await fetch(url, { signal: c.signal, headers: { "User-Agent": "NotYet-hackathon/0.1" } });
  } finally {
    clearTimeout(t);
  }
}

// Pull a price out of an archived product page. Order matters: structured data first.
export function extractPrice(html: string): number | null {
  const patterns = [
    /itemprop=["']price["'][^>]*content=["']\$?([0-9]{1,6}(?:\.[0-9]{1,2})?)/i,
    /property=["']product:price:amount["'][^>]*content=["']([0-9]{1,6}(?:\.[0-9]{1,2})?)/i,
    /"price"\s*:\s*"?\$?([0-9]{1,6}(?:\.[0-9]{1,2})?)"?/i,
    /class=["'][^"']*a-offscreen[^"']*["']>\$([0-9,]{1,7}(?:\.[0-9]{2})?)</i, // Amazon
  ];
  for (const re of patterns) {
    const m = html.match(re);
    if (!m) continue;
    const p = parseFloat(m[1].replace(/,/g, ""));
    if (p >= 1 && p <= 100000) return p;
  }
  return null;
}

// One snapshot per month since 2024, newest `max` of them, fetched 3 at a time.
export async function waybackHistory(rawUrl: string, retailer: string, max = 10): Promise<PricePoint[]> {
  const url = rawUrl.split("?")[0].split("#")[0];
  try {
    const cdx =
      `https://web.archive.org/cdx/search/cdx?url=${encodeURIComponent(url)}` +
      `&output=json&fl=timestamp,original&filter=statuscode:200&collapse=timestamp:6&from=2024`;
    const res = await fetchWithTimeout(cdx, 10000);
    if (!res.ok) return [];
    const rows = (await res.json()) as string[][];
    const snaps = rows.slice(1).slice(-max);
    const out: PricePoint[] = [];
    for (let i = 0; i < snaps.length; i += 3) {
      const batch = await Promise.all(
        snaps.slice(i, i + 3).map(async ([ts, orig]) => {
          try {
            const r = await fetchWithTimeout(`https://web.archive.org/web/${ts}id_/${orig}`, 10000);
            if (!r.ok) return null;
            const price = extractPrice(await r.text());
            if (!price) return null;
            const date = `${ts.slice(0, 4)}-${ts.slice(4, 6)}-${ts.slice(6, 8)}`;
            return { date, price, retailer, source: "wayback" } as PricePoint;
          } catch {
            return null;
          }
        }),
      );
      for (const b of batch) if (b) out.push(b);
    }
    return out;
  } catch {
    return [];
  }
}
