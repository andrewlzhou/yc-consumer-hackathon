# Store feasibility (2026-11-15)

- Surveyed 18 product URLs, plus direct-access checks on Macy's and Kohl's (both 403; no archive claim).
- Counts: successful archived HTML captures on distinct UTC days, 2025-11-15 through 2026-11-15.
- Exact URL unless marked *: American Eagle also includes tracking-query copies of the same path.
- Price yield is the final conservative reader over cached real snapshots, not a guarantee for a whole store.
- “was” counts only explicit list/strikethrough prices; an AggregateOffer's high price is not a “was” price.
- Raw measurements and sample timestamps: [survey fixture](../../convex/data/sources/stores/fixtures/store-survey.json).
- SerpApi cells marked “not tested” are unknown, not evidence that the store is absent.

| Store | URL tested | Archive days | Priced samples; was samples | SerpApi own-store feasibility |
|---|---|---:|---|---|
| Nike | [product](https://www.nike.com/t/air-force-1-07-mens-shoes-jBrhbr/CW2288-111) | 25 | 4/4; was 0 | Yes; 4 history changes on another AF1 colorway |
| Adidas | [product](https://www.adidas.com/us/samba-og-shoes/B75806.html) | 10 | 2/4; was 0 | Not tested |
| Lululemon | [product](https://shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012) | 38 | 1/3; was 0 | Yes; 2 changes on a markdown color, not this core page |
| H&M | [product](https://www2.hm.com/en_us/productpage.1206055002.html) | 3 | 2/2; was 1 | Not tested |
| American Eagle | [product](https://www.ae.com/us/en/p/men/jeans/baggy-loose-jeans/ae-baggy-jean/1114_7364_914) | 11* | 11/11; was 11 | Yes; 91 changes on Black 33×32, not this archived colorway |
| Uniqlo | [product](https://www.uniqlo.com/us/en/products/E424873-000/00) | 12 | 0/2; was 0 | Not tested |
| Gap | [product](https://www.gap.com/browse/product.do?pid=11802390320001) | 35 | 4/5; was 0 | Shopping yes; product lookup empty |
| Old Navy | [product](https://oldnavy.gap.com/browse/product.do?pid=402201002) | 2 | 1/2; was 0 | Shopping yes; product lookup empty |
| Zara | [product](https://www.zara.com/us/en/ankle-strap-heeled-sandals-p12310710.html) | 3 | 1/2; was 0 | Not tested |
| Sephora | [product](https://www.sephora.com/product/24-7-glide-on-eye-pencil-P133707) | 7 | 2/2; was 0 | Not tested |
| Ulta | [product](https://www.ulta.com/p/4-in-1-radiant-renewal-skincare-wand-pimprod2037834) | 93 | 4/4; was 0 | Not tested |
| Costco | [product](https://www.costco.com/apple-airpods-max-1st-generation.product.100779186.html) | 1 | 0/0 (not sampled); was 0 | Not tested |
| Home Depot | [product](https://www.homedepot.com/p/DEWALT-20V-MAX-Cordless-Drill-Impact-2-Tool-Combo-Kit-with-2-20V-1-3Ah-Batteries-Charger-and-Bag-DCK240C2/204373168) | 1 | 1/1; was 1 | Not tested |
| IKEA | [product](https://www.ikea.com/us/en/p/aerende-rug-high-pile-off-white-10605075/) | 30 | 2/2; was 0 | Not tested |
| Apple | [product](https://www.apple.com/shop/buy-airpods/airpods-pro-3) | 336 | 3/3; was 0 | Own offer absent from sampled shopping results |
| Samsung | [product](https://www.samsung.com/us/mobile-audio/galaxy-buds3-pro/buy/galaxy-buds3-pro-silver-sku-sm-r630nzaaxar/) | 22 | 5/5; was 0 | Not tested |
| New Balance | [product](https://www.newbalance.com/pd/9060/U9060V1-49464-PMG-NA.html) | 4 | 1/2; was 0 | Not tested |
| Lowe's | [product](https://www.lowes.com/pd/--/5013988281) | 33 | 2/2; was 0 | Not tested |

## Selection

- 1. American Eagle: 91 Google price changes over a year, a first-party offer, and frequent discount changes.
- 2. Nike: clean style-color prices and direct URL resolution; Zenvy is a real competitor to lululemon Align.
- 3. lululemon: dense archives, but reject mixed-price color variants. Align is the other side of the leggings comparison.
- 4. Apple: dense, parseable full-price history adds a baseline to the existing AirPods demo, not another new product.
- Ulta, IKEA, Samsung and Lowe's samples were mostly flat. Samsung's JSON-LD may be list price, so it is not trusted as a sale price.
- H&M and Zara had few captures; Uniqlo needs another parser. Gap and Old Navy's sampled Google product IDs failed.
- Adidas had two bot-wall stubs among four samples and blocked direct requests. It is not claimed as supported.
- Nike's shopping results led mostly to resellers. A separate AF1 Google product lists Nike with history, but is a different colorway.
- AE's Black 33×32 Google product is NOT merged with the archived gray/color-914 page; those prices differ.
- An earlier scout used the most common variant price. The shipped reader instead rejects differing prices without an exact variant match.

## Access and limits

- Direct requests from this machine worked for Nike and Apple. AE's old URL redirects to a category, so resolution uses Wayback.
- lululemon, Adidas, H&M and Uniqlo blocked direct fetches; archives can still be useful.
- 16 cached SerpApi research requests plus one deployment refresh request; no paid API. The free 250/month allowance is shared.
- See [store support](data-stores.md) for implemented behavior and limits.
