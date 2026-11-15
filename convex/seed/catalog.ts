// Demo catalog and sale calendar. Product titles, model numbers, MSRPs, and specs are real (researched 2026-11-15,
// sources in docs/backend/data-seed.md). Price histories are generated from tracks.ts and tagged source "seed".

type Spec = string | number | boolean;

export type SeedProduct = {
  key: string;
  title: string;
  brand: string;
  model: string;
  category: string;
  familyKey: string;
  variant?: Record<string, string>;
  aliases: string[];
  msrp: number;
  identifiers?: { gtin?: string; asin?: string };
  specs: Record<string, Spec>;
};

export const SEED_PRODUCTS: SeedProduct[] = [
  {
    key: "airpods-pro-3",
    title: "Apple AirPods Pro 3 Wireless Earbuds with Active Noise Cancellation",
    brand: "Apple",
    model: "MFHP4LL/A",
    category: "earbuds",
    familyKey: "apple-airpods-pro-3",
    aliases: ["AirPods Pro 3", "Apple AirPods Pro 3rd generation", "AirPods Pro 3 Heart Rate Sensing"],
    msrp: 249,
    specs: { chip: "H2", anc: true, batteryHoursAnc: 8, heartRateSensing: true, case: "USB-C", releaseDate: "2025-09-19" },
  },
  {
    key: "ipad-a16-128",
    title: "Apple iPad 11-inch (A16) Wi-Fi 128GB (2025, 11th generation)",
    brand: "Apple",
    model: "MD3Y4LL/A",
    category: "tablets",
    familyKey: "apple-ipad-11-a16-wifi",
    variant: { storage: "128GB" },
    aliases: ["iPad A16 128GB", "2025 Apple 11-inch iPad A16 Wi-Fi 128GB", "iPad 11th generation 128GB"],
    msrp: 449,
    specs: { chip: "A16", storageGb: 128, displayInches: 11, resolution: "2360x1640", wifi: "Wi-Fi 6", batteryHours: 10, touchId: true, releaseDate: "2025-03-12", launchPrice: 349 },
  },
  {
    key: "ipad-a16-256",
    title: "Apple iPad 11-inch (A16) Wi-Fi 256GB (2025, 11th generation)",
    brand: "Apple",
    model: "MD4G4LL/A",
    category: "tablets",
    familyKey: "apple-ipad-11-a16-wifi",
    variant: { storage: "256GB" },
    aliases: ["iPad A16 256GB", "2025 Apple 11-inch iPad A16 Wi-Fi 256GB", "iPad 11th generation 256GB"],
    msrp: 549,
    specs: { chip: "A16", storageGb: 256, displayInches: 11, resolution: "2360x1640", wifi: "Wi-Fi 6", batteryHours: 10, touchId: true, releaseDate: "2025-03-12", launchPrice: 449 },
  },
  {
    key: "ninja-af101",
    title: "Ninja AF101 Air Fryer with 4-Quart Ceramic Coated Basket, Black/Grey",
    brand: "Ninja",
    model: "AF101",
    category: "air-fryers",
    familyKey: "ninja-af101",
    aliases: ["Ninja 4 Qt Air Fryer", "Ninja AF101 4-in-1 Air Fryer"],
    msrp: 99.99,
    identifiers: { asin: "B07FDJMC9Q" },
    specs: { capacityQt: 4, watts: 1550, tempRangeF: "105-400", functions: "air fry, roast, reheat, dehydrate", dishwasherSafe: true },
  },
  {
    key: "bose-qcu-2",
    title: "Bose QuietComfort Ultra Headphones (2nd Gen) Wireless Noise Cancelling Over-Ear Headphones",
    brand: "Bose",
    model: "890101-0100",
    category: "headphones",
    familyKey: "bose-qc-ultra-headphones-2",
    aliases: ["Bose QuietComfort Ultra Headphones II", "Bose QC Ultra 2nd Gen", "Bose QuietComfort Ultra 2"],
    msrp: 449,
    specs: { anc: true, batteryHours: 30, spatialAudio: true, usbCAudio: "lossless", quickCharge: "15 min = 2.5 h", releaseDate: "2025-10-02" },
  },
  {
    key: "sony-xm5",
    title: "Sony WH-1000XM5 Wireless Noise Canceling Over-Ear Headphones",
    brand: "Sony",
    model: "WH-1000XM5",
    category: "headphones",
    familyKey: "sony-wh-1000xm5",
    aliases: ["Sony XM5", "Sony WH1000XM5"],
    msrp: 399.99,
    identifiers: { asin: "B09XS7JWHH" },
    specs: { anc: true, batteryHours: 30, codec: "LDAC", weightGrams: 250, processor: "QN1", microphones: 8, releaseDate: "2022-05" },
  },
  {
    key: "sony-xm6",
    title: "Sony WH-1000XM6 Wireless Noise Canceling Over-Ear Headphones",
    brand: "Sony",
    model: "WH1000XM6/B",
    category: "headphones",
    familyKey: "sony-wh-1000xm6",
    aliases: ["Sony XM6", "Sony WH1000XM6"],
    msrp: 459.99,
    specs: { anc: true, batteryHours: 30, codec: "LDAC", weightGrams: 254, processor: "QN3", microphones: 12, foldable: true, releaseDate: "2025-05-15" },
  },
  {
    key: "ember-mug-2-10oz",
    title: "Ember Mug 2 Temperature Control Smart Mug, 10 oz",
    brand: "Ember",
    model: "CM191000US",
    category: "smart-mugs",
    familyKey: "ember-mug-2",
    variant: { capacity: "10oz" },
    aliases: ["Ember Mug²", "Ember Mug 2 10oz", "Ember Temperature Control Smart Mug 2"],
    msrp: 129.95,
    specs: { capacityOz: 10, batteryMinutes: 90, appControl: true, material: "stainless steel" },
  },
];

export const SEED_RETAILERS = ["target", "walmart", "bestbuy", "amazon"];

type SeedEvent = {
  name: string;
  series: string;
  retailerSlug?: string;
  start: string;
  end: string;
  kind: "national" | "retailer" | "brand";
  dateConfidence: "confirmed" | "estimated";
};

// Real dates (confirmed from retailer press pages or news) unless marked estimated.
export const SEED_EVENTS: SeedEvent[] = [
  { name: "Black Friday 2025", series: "black-friday", start: "2025-11-28", end: "2025-11-28", kind: "national", dateConfidence: "confirmed" },
  { name: "Cyber Monday 2025", series: "cyber-monday", start: "2025-12-01", end: "2025-12-01", kind: "national", dateConfidence: "confirmed" },
  { name: "Best Buy Black Friday Sale 2025", series: "bestbuy-black-friday", retailerSlug: "bestbuy", start: "2025-11-20", end: "2025-11-29", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Presidents Day 2026", series: "presidents-day", start: "2026-02-13", end: "2026-02-16", kind: "national", dateConfidence: "confirmed" },
  { name: "Best Buy Memorial Day Sale 2026", series: "memorial-day", retailerSlug: "bestbuy", start: "2026-05-19", end: "2026-05-25", kind: "retailer", dateConfidence: "estimated" },
  { name: "Memorial Day 2026", series: "memorial-day", start: "2026-05-22", end: "2026-05-25", kind: "national", dateConfidence: "confirmed" },
  { name: "Walmart Deals June 2026", series: "summer-sales", retailerSlug: "walmart", start: "2026-06-22", end: "2026-06-28", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Target Circle Deal Days June 2026", series: "summer-sales", retailerSlug: "target", start: "2026-06-22", end: "2026-06-26", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Amazon Prime Day 2026", series: "summer-sales", retailerSlug: "amazon", start: "2026-06-23", end: "2026-06-26", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Best Buy Tech Fest June 2026", series: "summer-sales", retailerSlug: "bestbuy", start: "2026-06-23", end: "2026-06-26", kind: "retailer", dateConfidence: "estimated" },
  { name: "Labor Day 2026", series: "labor-day", start: "2026-09-04", end: "2026-09-07", kind: "national", dateConfidence: "confirmed" },
  { name: "Amazon Prime Big Deal Days 2026", series: "fall-sales", retailerSlug: "amazon", start: "2026-10-06", end: "2026-10-07", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Target Circle Deal Days October 2026", series: "fall-sales", retailerSlug: "target", start: "2026-10-06", end: "2026-10-07", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Best Buy Early Black Friday 2026", series: "early-black-friday", retailerSlug: "bestbuy", start: "2026-11-06", end: "2026-11-18", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Walmart Early Black Friday 2026", series: "early-black-friday", retailerSlug: "walmart", start: "2026-11-12", end: "2026-11-15", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Amazon Black Friday Week 2026", series: "black-friday", retailerSlug: "amazon", start: "2026-11-19", end: "2026-11-30", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Best Buy Black Friday Doorbusters 2026", series: "bestbuy-black-friday", retailerSlug: "bestbuy", start: "2026-11-19", end: "2026-11-28", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Walmart Black Friday Deals 2026", series: "black-friday", retailerSlug: "walmart", start: "2026-11-23", end: "2026-11-29", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Black Friday 2026", series: "black-friday", start: "2026-11-27", end: "2026-11-27", kind: "national", dateConfidence: "confirmed" },
  { name: "Cyber Monday 2026", series: "cyber-monday", start: "2026-11-30", end: "2026-11-30", kind: "national", dateConfidence: "confirmed" },
  { name: "Walmart Cyber Monday 2026", series: "cyber-monday", retailerSlug: "walmart", start: "2026-11-30", end: "2026-12-02", kind: "retailer", dateConfidence: "confirmed" },
  { name: "Best Buy Cyber Week 2026", series: "cyber-monday", retailerSlug: "bestbuy", start: "2026-12-01", end: "2026-12-06", kind: "retailer", dateConfidence: "confirmed" },
];
