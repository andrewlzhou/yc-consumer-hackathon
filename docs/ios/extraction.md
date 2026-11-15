# On-device extraction

- Code: `ios/ShopperKit/Sources/ShopperKit` (`TextRecognizer`, `PriceText`, `ProductExtractor`).
- OCR: Vision `RecognizeTextRequest`, fast level, language correction off (model numbers survive), minimum
  text height 0.8% of the image. Boxes are converted to a top-left origin. About 0.07-0.15 s per phone-sized
  screenshot on an M4 Mac (release build); phone timing still to be measured.

## Rules (blank beats wrong)

- Prices: `# On-device extraction

- Code: `ios/ShopperKit/Sources/ShopperKit` (`TextRecognizer`, `PriceText`, `ProductExtractor`).
- OCR: Vision `RecognizeTextRequest`, fast level, language correction off (model numbers survive), minimum
  text height 0.8% of the image. Boxes are converted to a top-left origin. About 0.07-0.15 s per phone-sized
  screenshot on an M4 Mac (release build); phone timing still to be measured.

 amounts only; `C# On-device extraction

- Code: `ios/ShopperKit/Sources/ShopperKit` (`TextRecognizer`, `PriceText`, `ProductExtractor`).
- OCR: Vision `RecognizeTextRequest`, fast level, language correction off (model numbers survive), minimum
  text height 0.8% of the image. Boxes are converted to a top-left origin. About 0.07-0.15 s per phone-sized
  screenshot on an M4 Mac (release build); phone timing still to be measured.

/`A# On-device extraction

- Code: `ios/ShopperKit/Sources/ShopperKit` (`TextRecognizer`, `PriceText`, `ProductExtractor`).
- OCR: Vision `RecognizeTextRequest`, fast level, language correction off (model numbers survive), minimum
  text height 0.8% of the image. Boxes are converted to a top-left origin. About 0.07-0.15 s per phone-sized
  screenshot on an M4 Mac (release build); phone timing still to be measured.

, coupons (`-$50`), "2 for $5", ranges, financing, savings, unit prices,
  plans, shipping, cart totals and taxes are noise. Thousands always use a comma.
- Superscript cents: Vision's per-glyph boxes show when the last two digits of `$27900` are smaller or raised, and
  the recognizer writes `$279.00`. Any other comma-less amount of 4+ digits (`$1099`) is ambiguous: no price.
- Current price: the tallest plain price. Two equal-size prices side by side (strike first or last) are a sale pair:
  the lower is today's price, the higher the original (if at most 5x). Two other big prices: no price.
- Original price: a "was/reg/list/compare" price near it, else a higher price later on the same line, or a lone
  price-only box right beside or below it. Variant, plan and seller prices carry words, so they never count.
- Listings, carousels, carts and checkout screens: no product.
- Title: wrapped lines joined; big, long text within 25% of the screen height of the price wins; store chrome,
  delivery, ratings and bot-check text never count. Without a price only headline-size text counts.
- Privacy: notification banners, greetings, emails, phone numbers, street addresses, ZIP codes and "Name: text"
  lines are dropped before choosing a title or fallback lines.
- Store: a domain on screen (Safari) first, then a store name outside the product title.
- No title but a price: up to 5 pruned lines near the price go as `ocrLines`. No price: none is sent.
- Apple's on-device model is not used: Ruhaan's iPhone 14 (A15) can't run it, and it could undo a deliberate blank.

## Fixtures and accuracy

- `Tests/ShopperKitTests/Fixtures`: 8 OCR dumps of public store pages (headless Chrome at iPhone size,
  location redacted) and 7 synthetic layouts. Only text lines and boxes are committed, never images.
- Current result (15 fixtures): prices 15/15, original price 15/15, store 15/15, product vs no product
  15/15, title 14/15 (Sony store page: a feature heading is taken as the title; recorded as a known miss).
- `AdversarialTests.swift`: the YCCO-11 review cases (strike-first, flat superscript, lost comma, banner and
  address text, variant/plan prices, cart subtotal, store name in title) all pass.
- Make a fixture: `swift run ocrdump shot.png > Fixtures/name.json`, then add an `expected` block.
