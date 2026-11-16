import { describe, expect, test } from "vitest";
import real from "./fixtures/store-pages.json";
import { readStorePage } from "./read";
import { readStructured } from "./structured";
import { parseUrl } from "./url";

const PEG41 = "https://www.nike.com/t/pegasus-41-mens-road-running-shoes-LMhfRGdO/FD2722-001";
const PEG42 = "https://www.nike.com/t/pegasus-42-mens-road-running-shoes-S1bYkOza/II7210-100";
const AE = "https://www.ae.com/us/en/p/men/jeans/baggy-loose-jeans/ae-baggy-jean/1114_7364_914";

describe("generic store page reader (JSON-LD, then meta tags)", () => {
  test("ProductGroup with variants: lululemon Align at its one price", () => {
    expect(readStructured(real.lululemonAlign)).toMatchObject({ title: 'lululemon Align High-Rise Pant 25"', brand: "lululemon", price: 98, originalPrice: null });
  });

  test("Apple and Home Depot, including a strikethrough price in priceSpecification", () => {
    expect(readStructured(real.appleAirPodsPro3)).toMatchObject({ title: "AirPods Pro 3", price: 249 });
    expect(readStructured(real.homeDepotDewalt)).toMatchObject({ brand: "DEWALT", price: 159, originalPrice: 239 });
  });

  test("product meta tags when there is no JSON-LD, and non-USD offers are ignored", () => {
    const meta = '<meta property="og:title" content="Linen Shirt &amp; Tie"><meta property="product:price:amount" content="39.90"><meta property="product:price:currency" content="USD">';
    expect(readStructured(meta)).toMatchObject({ title: "Linen Shirt & Tie", price: 39.9, pattern: "meta" });
    const euro = '<script type="application/ld+json">{"@type":"Product","name":"X","offers":{"@type":"Offer","price":"20","priceCurrency":"EUR"}}</script>';
    expect(readStructured(euro).price).toBeNull();
  });
});

describe("store extras", () => {
  test("Nike: the URL's style-color, with its full price as the was-price", () => {
    expect(readStorePage("nike", real.nikePeg41, PEG41)).toMatchObject({ title: "Nike Pegasus 41 Men's Road Running Shoes", price: 108.97, originalPrice: 145, blocked: false });
    expect(readStorePage("nike", real.nikePeg42, PEG42)).toMatchObject({ price: 123.97, originalPrice: 145 });
  });

  test("American Eagle: list price from the size rows", () => {
    expect(readStorePage("ae", real.aeBaggy, AE)).toMatchObject({ title: "AE Baggy Jean", price: 24.99, originalPrice: 49.95 });
  });

  test("a non-USD Nike price cannot enter the USD fallback", () => {
    expect(readStorePage("nike", real.nikePeg41.replace(/USD/g, "EUR"), PEG41).price).toBeNull();
    expect(parseUrl(AE.replace("/us/en/", "/ca/en/"))).toBeNull();
    expect(parseUrl(PEG41.replace("/t/", "/gb/t/"))).toBeNull();
  });

  test("an archived bot-wall stub is blocked, not a missing price", () => {
    expect(readStorePage("adidas", real.adidasStub)).toMatchObject({ price: null, blocked: true });
  });
});

describe("parseUrl (no network)", () => {
  test("brand stores and existing retailers", () => {
    expect(parseUrl(PEG42)).toEqual({ retailer: "nike", productCode: "II7210-100", titleHint: "Nike pegasus 42 mens road running shoes", url: PEG42 });
    expect(parseUrl(AE + "?menu=cat4840004")).toMatchObject({ retailer: "ae", productCode: "1114_7364_914", url: AE });
    expect(parseUrl("https://shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012?color=0001")).toMatchObject({ retailer: "lululemon", productCode: "prod2020012" });
    expect(parseUrl("https://shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012?sz=4&color=0001&utm_source=share")?.url).toBe("https://shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012?color=0001&sz=4");
    expect(parseUrl("https://www.apple.com/shop/buy-airpods/airpods-pro-3")).toMatchObject({ retailer: "apple", titleHint: "Apple airpods pro 3" });
    expect(parseUrl("https://www.amazon.com/Sony-WH-1000XM5-Headphones/dp/B09XS7JWHH/ref=sr_1_1")).toMatchObject({ retailer: "amazon", productCode: "B09XS7JWHH", url: "https://www.amazon.com/dp/B09XS7JWHH" });
    expect(parseUrl("https://www.bestbuy.com/site/apple-airpods-pro-3/6376563.p?skuId=6376563")).toMatchObject({ retailer: "bestbuy", productCode: "6376563", titleHint: "apple airpods pro 3" });
  });

  test("unsupported hosts and junk are null", () => {
    expect(parseUrl("https://www.zara.com/us/en/sandals-p12310710.html")).toBeNull();
    expect(parseUrl("not a url")).toBeNull();
    expect(parseUrl("javascript:alert(1)")).toBeNull();
    expect(parseUrl("https://www.nike.com/")).toBeNull();
    expect(parseUrl("https://untrusted.nike.com/t/shoes-XyzAbc/AA0000-001")).toBeNull();
    expect(parseUrl("https://www.nike.com:444/t/shoes-XyzAbc/AA0000-001")).toBeNull();
    expect(parseUrl("https://user:password@www.nike.com/t/shoes-XyzAbc/AA0000-001")).toBeNull();
  });

  test("an AggregateOffer range is not a was-price", () => {
    const range = '<script type="application/ld+json">{"@type":"Product","offers":{"@type":"AggregateOffer","lowPrice":20,"highPrice":40,"priceCurrency":"USD"}}</script>';
    expect(readStructured(range)).toMatchObject({ price: null, originalPrice: null });
  });

  test("different variant prices are not collapsed into a guessed current price", () => {
    const variants = '<script type="application/ld+json">{"@type":"ProductGroup","hasVariant":[{"@type":"Product","sku":"AA1234","offers":{"price":20}},{"@type":"Product","sku":"BB5678","offers":{"price":40}}]}</script>';
    expect(readStructured(variants).price).toBeNull();
    expect(readStructured(variants, "https://www.nike.com/t/shoe/AA1234").price).toBe(20);
  });

  test("lululemon color and size select one offer, and unknown variants never use meta fallback", () => {
    const url = "https://shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012";
    expect(readStructured(real.lululemonAlign, url + "?color=0001&sz=10")).toMatchObject({ price: 98 });
    expect(readStructured(real.lululemonAlign + '<meta property="product:price:amount" content="98">', url + "?color=unseen&sz=10").price).toBeNull();
    expect(readStructured(real.lululemonAlign, url + "?color=0001&sz=unseen").price).toBeNull();
  });
});
