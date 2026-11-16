# Real-data demo set

- Five electronics products below, plus [three store products](data-stores-live.md), picked from real history. Code: `convex/data/demo.ts`.
- Load one product: `npx convex run data/demo:ingest '{"key":"sony-xm5"}'` (1 SerpApi search, plus Wayback pages).
- Daily cron (`refresh demo prices`, 14:00 UTC): six Google-enabled products (the five below plus AE), up to 180 searches/month before other usage.
- Turning a product real deletes its seed points; `npm run seed` then skips it. Other catalog products stay seed.

## Where the numbers come from

- Google price history via SerpApi `google_product` (source `api`): each store's price on the days it changed,
  about a year back. We expand each change into one point per day until the next change, so medians are time-weighted.
  Only known first-party retailers are stored, including the four verified store slugs; marketplace sellers are skipped.
- Current offers from the same call (source `api`), and archived product pages from the Wayback Machine (source `scrape`).

## What the deployment holds (365-day window, 2026-11-15)

| Product | Real points (changes) | Sources | Today | Supports |
|---|---|---|---|---|
| Sony WH-1000XM5 | 720 (49 changes) | Google: Best Buy, Target; Wayback: Best Buy 4, Walmart 2 | Best Buy $198, "was $398" | BUY_NOW |
| Sony WH-1000XM6 | 706 (52 changes) | Google: Best Buy, Target | Best Buy $378, "was $458" | CONSIDER_ALTERNATIVE (XM5) |
| Bose QC Ultra (2nd Gen) | 366 (46 changes) | Google: Best Buy | Best Buy $339.99, "was $449" | BUY_NOW |
| AirPods Pro 3 | 393 (52 changes) | Google: Target; Wayback: Best Buy 27 | Target $179.99, "was $249.99" | BUY_NOW |
| PS5 Slim Disc | 1 | Google Shopping offer: Walmart | Walmart $649 | INVESTIGATE |

- XM5: $198 ties the 12-month low (also hit in June), 29% under the typical $278. "Was $398" was charged on 16% of days.
- XM6: $378 ties its low but is only 5.5% under typical ($399.99); the XM5 is $198 today.
- Bose: $339.99 is the lowest price in the year, 15% under typical ($399.99). "Was $449" was charged on 45% of days.
- AirPods Pro 3: $179.99 is $0.99 above the low ($179), 18% under typical. Best Buy archive pages show $249.99 most days.
- PS5 Slim: Google has no price history for it, so one offer is all the evidence there is.
- Scanning a store still at full price gives a real "buy elsewhere" case: XM5 at Target is $399.99 while Best Buy is $198.

## What real data cannot show today

- These electronics do not provide "WAIT for Black Friday": they are at early-sale lows (XM5 was $248 last year).
  The added [AE Baggy Jean](data-stores-live.md) does: $35.97 now versus $29.97 at Black Friday 2025; both model tiers returned WAIT.
- A "was" price that was never charged: every claimed price here was charged on some days (16-45%).
- Use the seed products (iPad, Ninja, Ember; labeled sample data) for those scenarios, and say they are samples.

## Feasibility notes

- SerpApi: 2 searches find a product (shopping search, then product page); afterwards 1 per refresh.
- Wayback: Amazon captures show no buy box, so no prices; Best Buy pages parse (29/29 for AirPods Pro 3);
  Walmart parses but has 1-2 captures a year. Newer Target pages render the price client-side.
- Ninja AF101 has no first-party offers on Google Shopping any more (only eBay, Mercari, Home Depot), so refresh records 0.
