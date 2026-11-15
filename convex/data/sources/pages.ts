// Price extraction from retailer product-page HTML (live pages or Wayback Machine snapshots).
// Retailers change markup often, so each parser tries several known patterns and returns null rather than guess.

export type PageRead = {
  price: number | null;
  originalPrice: number | null;
  inStock: boolean | null;
  blocked: boolean;
  pattern: string | null;
};

const money = (s: string | undefined) => {
  if (!s) return null;
  const n = Number(s.replace(/[,$\s]/g, ""));
  return Number.isFinite(n) && n > 0 ? n : null;
};

const BLOCKED = /captcha|robot check|px-captcha|access to this page has been denied|are you a human|verify you are human/i;
const OUT_OF_STOCK = /currently unavailable|out of stock|sold out|"availabilityStatus":"OUT_OF_STOCK"|"availability_status":"OUT_OF_STOCK"/i;

function firstMatch(html: string, patterns: [string, RegExp][]): { value: number; pattern: string } | null {
  for (const [name, re] of patterns) {
    const m = html.match(re);
    const value = money(m?.[1]);
    if (value !== null) return { value, pattern: name };
  }
  return null;
}

function amazon(html: string) {
  const core = html.match(/id="(?:corePrice_feature_div|corePriceDisplay_desktop_feature_div|corePrice_desktop|apex_desktop)"([\s\S]{0,8000})/)?.[1] ?? "";
  const price = firstMatch(core, [
    ["amazon.core.priceToPay", /priceToPay[\s\S]{0,400}?class="a-offscreen">\s*\$([\d,]+\.\d{2})/],
    ["amazon.core.offscreen", /class="a-offscreen">\s*\$([\d,]+\.\d{2})/],
  ]) ?? firstMatch(html, [
    ["amazon.priceblock", /id="priceblock_(?:ourprice|dealprice|saleprice)"[^>]*>\s*\$([\d,]+\.\d{2})/],
    ["amazon.json.priceAmount", /"priceAmount":\s*([\d.]+)/],
  ]);
  const was = firstMatch(core, [
    ["amazon.core.strike", /data-a-strike="true"[^>]*>\s*<span class="a-offscreen">\s*\$([\d,]+\.\d{2})/],
    ["amazon.core.basis", /basisPrice[\s\S]{0,400}?class="a-offscreen">\s*\$([\d,]+\.\d{2})/],
    ["amazon.core.listPrice", /(?:List Price|Typical price|Was Price)[\s\S]{0,300}?\$([\d,]+\.\d{2})/],
  ]);
  return { price, was };
}

function walmart(html: string) {
  const price = firstMatch(html, [
    ["walmart.currentPrice", /"currentPrice":\{[^}]*?"price":([\d.]+)/],
    ["walmart.itemprop", /itemprop="price"[^>]*content="([\d.]+)"/],
  ]);
  const was = firstMatch(html, [
    ["walmart.wasPrice", /"wasPrice":\{[^}]*?"price":([\d.]+)/],
    ["walmart.listPrice", /"listPrice":\{[^}]*?"price":([\d.]+)/],
  ]);
  return { price, was };
}

function target(html: string) {
  const unescaped = html.replace(/\\"/g, '"');
  const price = firstMatch(unescaped, [
    ["target.current_retail", /"current_retail":([\d.]+)/],
    ["target.formatted_current", /"formatted_current_price":"\$([\d.,]+)"/],
  ]);
  const was = firstMatch(unescaped, [
    ["target.reg_retail", /"reg_retail":([\d.]+)/],
    ["target.formatted_comparison", /"formatted_comparison_price":"\$([\d.,]+)"/],
  ]);
  return { price, was };
}

function bestbuy(html: string) {
  const price = firstMatch(html, [
    ["bestbuy.newBuyingOption", /"type":"New","product":\{[^{}]*"price":\{[^{}]*"customerPrice":([\d.]+)/],
    ["bestbuy.customerPrice", /"customerPrice":([\d.]+)/],
    ["bestbuy.currentPrice", /"currentPrice":([\d.]+)/],
    ["bestbuy.ldjson", /"@type":"Offer"[\s\S]{0,300}?"price":"?([\d.]+)/],
  ]);
  const was = firstMatch(html, [["bestbuy.regularPrice", /"regularPrice":([\d.]+)/]]);
  return { price, was };
}

// Structured data (schema.org Offer) is a last resort that works on many retailers.
function ldJson(html: string) {
  return firstMatch(html, [["ldjson.offer", /"@type"\s*:\s*"Offer"[\s\S]{0,400}?"price"\s*:\s*"?([\d.]+)/]]);
}

const PARSERS: Record<string, (html: string) => { price: { value: number; pattern: string } | null; was: { value: number; pattern: string } | null }> = {
  amazon,
  walmart,
  target,
  bestbuy,
};

export function readProductPage(retailerSlug: string, html: string): PageRead {
  const head = html.slice(0, 30000);
  const blocked = BLOCKED.test(head) && html.length < 200000;
  const parser = PARSERS[retailerSlug];
  const found = parser ? parser(html) : { price: null, was: null };
  const price = found.price ?? ldJson(html);
  const was = found.was && price && found.was.value > price.value ? found.was : null;
  const inStock = price ? true : OUT_OF_STOCK.test(html) ? false : null;
  return {
    price: price?.value ?? null,
    originalPrice: was?.value ?? null,
    inStock,
    blocked: blocked && !price,
    pattern: price?.pattern ?? null,
  };
}
