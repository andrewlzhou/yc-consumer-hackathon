import type { SeedProduct } from "../../../seed/catalog";

// Brand-store demo products, picked 2026-11-15 by real archived history (docs/backend/data-stores.md).
// Titles and codes come from the stores' own pages; msrp is the store's list price on those pages.
export type StoreDemoProduct = SeedProduct & { googleProductId?: string; serpapi?: boolean; wayback?: { retailer: string; url: string; prefix?: boolean }[] };

export const STORE_DEMO_PRODUCTS: StoreDemoProduct[] = [
  {
    key: "ae-baggy-jean",
    title: "AE Baggy Jean Men's",
    brand: "American Eagle",
    category: "jeans",
    familyKey: "ae-baggy-jean-mens",
    model: "google-8864934752646101426",
    variant: { color: "Black", size: "33 X 32" },
    aliases: ["AE Baggy Jean", "American Eagle Baggy Jean", "AE Men's Baggy Jean"],
    msrp: 59.95,
    specs: { fit: "baggy", gender: "men", store: "American Eagle" },
    googleProductId: "8864934752646101426",
  },
  {
    key: "lululemon-align-25",
    title: 'lululemon Align High-Rise Pant 25"',
    brand: "lululemon",
    model: "prod2020012",
    category: "leggings",
    familyKey: "lululemon-align-high-rise-pant-25",
    aliases: ["lululemon Align Pant 25", "Align High-Rise Pant 25 inch", "lululemon Align leggings 25"],
    msrp: 98,
    specs: { inseamInches: 25, rise: "high", gender: "women" },
    serpapi: false,
    wayback: [{ retailer: "lululemon", url: "https://shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012", prefix: true }],
  },
  {
    // Competitor to Align at another store.
    key: "nike-zenvy-leggings",
    title: "Nike Zenvy Women's High-Waisted Full-Length Leggings",
    brand: "Nike",
    model: "II2862-010",
    category: "leggings",
    familyKey: "nike-zenvy-high-waisted-full-length-leggings",
    aliases: ["Nike Zenvy leggings", "Nike Zenvy high-waisted leggings", "Zenvy full-length leggings"],
    msrp: 105,
    specs: { rise: "high", length: "full", gender: "women", styleColor: "II2862-010" },
    serpapi: false,
    wayback: [{ retailer: "nike", url: "https://www.nike.com/t/zenvy-womens-high-waisted-full-length-leggings-with-no-front-seam-PrjzuxGX/II2862-010", prefix: true }],
  },
];
