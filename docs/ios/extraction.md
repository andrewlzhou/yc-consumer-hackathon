# On-device extraction

- Code: `ios/ShopperKit/Sources/ShopperKit` (`TextRecognizer`, `PriceText`, `ProductExtractor`).
- OCR: Vision `RecognizeTextRequest`, fast level, language correction off (model numbers survive), minimum
  text height 0.8% of the image. Boxes are converted to a top-left origin. About 0.07-0.15 s per phone-sized
  screenshot on an M4 Mac (release build); phone timing still to be measured.

## Rules (blank beats wrong)

- Prices: `$` amounts only. Thousands always use a comma, so `$27900` is read as $279.00 (superscript
  cents); `$1.991mo` and ranges like `$39.95 - $59.95` are dropped.
- Noise: financing (/mo, payments, Affirm), shipping, savings ("Save $120"), unit prices (/oz), plans,
  gift cards, used/refurbished offers.
- Current price: the tallest plain price. Original: a "was/reg/list/compare" price near it, else one unlabeled,
  smaller, higher price right beside it (Walmart's crossed-out price).
- Listing pages: the tallest price shares its row with another, or many same-size prices -> no product.
- Title: wrapped lines are joined; big, long text near (ideally above) the price wins; store chrome, delivery,
  ratings and bot-check text never count. Without a price only headline-size text counts.
- Store: a domain on screen (Safari) first, then a store name that isn't also a brand.
- No title but a price: up to 12 pruned lines go to the backend as `ocrLines`. No price: none is sent.

## Fixtures and accuracy

- `Tests/ShopperKitTests/Fixtures`: 8 OCR dumps of public store pages (headless Chrome at iPhone size,
  location redacted) and 7 synthetic layouts. Only text lines and boxes are committed, never images.
- Current result (15 fixtures): prices 15/15, original price 15/15, store 15/15, product vs no product
  15/15, title 14/15 (Sony store page: a feature heading is taken as the title; recorded as a known miss).
- Make a fixture: `swift run ocrdump shot.png > Fixtures/name.json`, then add an `expected` block.
