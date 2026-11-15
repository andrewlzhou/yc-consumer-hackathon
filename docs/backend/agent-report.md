# Shopping agent: detailed report and product links

## GET /report?productId=

- On demand, never on the live path. Returns the newest analysis (the full one when both are equally new),
  `pending` while a full run is queued or running, and a `chart`.
- `analysis.report`: the model's sections, each citing evidence ids: priceAssessment, discount (status and signals),
  forecast, retailers, competitors (value reasoning), recommendation.
- `analysis.insights` (`agent/insights.ts`): exact sections computed in code from the same evidence the model cites.
  - `forecast`: will a better price come. Range (low, high) from this product's lows at past editions of an upcoming
    event, else from its recent sale cycle; `byDate`, `outlook`, `confidence` (more past editions and more retailers
    beating today's price raise it; never above 0.8).
  - `retailerPatterns`: per retailer, latest, typical and lowest price, sale episodes, median sale depth, last sale,
    advertised discounts, and how often the price rose before a sale.
  - `discountAuthenticity`: was-price charged share, claimed versus real discount, sale frequency, routine discounting,
    and every pre-sale price hike.
  - `competitorComparison`: each catalog comparable with price gap, savings percent, similarity, and a spec-by-spec table.
- `chart` (`agent/chart.ts`): last 365 days as step series per retailer (a point only when the price changed, plus the
  latest), lowest and typical price, sale events for shading, counts by source, and `isSampleData`.
- Older analyses have `insights: null`.

## Product links (`url`)

- Share menu and Safari send a link. `/analyze` accepts `url` with or without a title (http or https only).
- A link resolved before (`resolvedUrls`, host plus path) identifies the product on the live path with one indexed read.
- A new link is resolved in the background by `agent/urls:resolveInBackground`: it calls the stores thread's
  `data/sources/stores/resolve:resolveUrl` (it may fetch the page), falls back to the extract's title, stores the
  mapping, and starts the full run when the scan had no match. A missing or failing resolver only loses that fallback.
- A link alone that is not resolved yet gets INVESTIGATE with `reportStatus: "pending"`; sending it again later is
  answered from the mapping.
