import { KNOWN_RETAILERS } from "../data/retailers";

// Text the phone read off a screen is untrusted: a notification banner, an account header or a store's home screen can
// arrive as the "title" when no product title was visible (iOS review H3, CON-10). Such text must never become a
// catalog product, a stored scan title, or a paid model or search call. A blocklist alone has gaps, so a title is
// trusted only when it also carries a product signal: a model code or multi-digit number, or a product word.

const US_STATES = "AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY";
const STREET = "st|street|ave|avenue|rd|road|blvd|boulevard|dr|drive|ln|lane|way|pkwy|parkway|ct|court|pl|place|hwy|highway|loop|cir|circle|ter|terrace|trl|trail|sq|square|plz|plaza";

const PERSONAL = [
  /@/,
  /\d{10,11}/,
  /\(?\b\d{3}\)?[\s.-]?\d{3}[\s.-]\d{4}\b/,
  /\(\d{3}\)\s?\d{3}/,
  new RegExp(`\\b(?:${US_STATES.replace(/ /g, "|")})\\s+\\d{5}(?:-\\d{4})?\\b`),
  // A greeting followed by punctuation, an emoji or a capitalized name: "Hello, Ruhaan", "Hi👋", but not "Hello Kitty Plush".
  /^\s*(?:hello|hi|hey|welcome(?: back)?|good (?:morning|afternoon|evening))(?:\s*[^\p{L}\p{N}\s-]|\s*$)/iu,
  /\b(?:deliver(?:ing)?|ship(?:ping)?)[\s-]+to\b/i,
  new RegExp(`\\b\\d{1,5}\\s+(?:[a-z]+\\s+){1,3}(?:${STREET})\\b`, "i"),
  /\b(?:apt|apartment|suite|unit)\s*#?\s*\d+/i,
  /\b(?:now|\d{1,2}\s?(?:m|min|mins|h|hr|hrs)\s+ago|yesterday)\s+[A-Z][\w' ]{0,30}:\s/,
  /^\s*[A-Z][a-z]+(?:\s[A-Z][a-z]+)?:\s+[a-z]/,
  /\b(?:are you|can you|picking up|on my way|call me|text me|sign(?:ed)? in as|your account|your orders|order #|call\s+\+?\d)/i,
];

// Words a store's own screens show around a product, never a product on their own.
const CHROME = new Set("app apps home homepage shop shopping store stores online official site deals deal day today cart bag search sign in account menu welcome to the com www and of for circle prime plus rewards membership member card wallet orders order list lists saved".split(" "));
const STORE_NAMES = KNOWN_RETAILERS.flatMap((r) => [r.name, r.slug, r.domain ?? "", ...r.aliases]).filter(Boolean).map((s) => s.toLowerCase()).sort((a, b) => b.length - a.length);

// Nouns that name a kind of product, for titles without a model number ("Nike Zenvy leggings", "Ember Mug").
const PRODUCT_WORDS = new Set(`headphones headphone earbuds earphones buds airpods speaker speakers soundbar tv television laptop notebook
tablet ipad iphone phone smartphone watch smartwatch camera lens console playstation xbox switch controller monitor keyboard mouse
charger cable adapter router printer drone vacuum fryer blender mixer toaster kettle cooker maker microwave pan pot skillet knife
mug cup tumbler bottle lamp chair desk table mattress pillow blanket towel sheets toy plush lego doll puzzle game book
jeans jean pants pant trousers leggings shorts shirt tee hoodie sweatshirt sweater jacket coat vest dress skirt bra underwear
shoes shoe sneakers sneaker boots boot sandals slippers socks sox hat cap bag backpack wallet purse sunglasses glasses
perfume cologne lotion shampoo conditioner serum cream sunscreen razor toothbrush vitamins supplement protein coffee tea
bike bicycle helmet tent grill sofa couch rug headset ssd drive`.split(/\s+/));

// NFKC folds fullwidth and compatibility letters; format characters such as zero-width spaces are removed.
export function normalizeScreenText(text: string): string {
  return text.normalize("NFKC").replace(/\p{Cf}/gu, "").replace(/\s+/g, " ").trim();
}

export function looksPersonal(text: string): boolean {
  const t = normalizeScreenText(text);
  return PERSONAL.some((re) => re.test(t));
}

// "Best Buy App", "Amazon Prime", "Target Circle": nothing left once store names and app chrome are removed.
export function isStoreChrome(text: string): boolean {
  let rest = ` ${normalizeScreenText(text).toLowerCase().replace(/[^a-z0-9.]+/g, " ")} `;
  for (const name of STORE_NAMES) rest = rest.split(` ${name} `).join(" ");
  return rest.replace(/\./g, " ").split(/\s+/).filter((w) => w.length > 1 && !CHROME.has(w)).length === 0;
}

// A model code (XM5, AF101, 128GB, II2862-010), a number of two or more digits, or a product word.
export function hasProductSignal(text: string): boolean {
  const words = normalizeScreenText(text).toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
  return words.some((w) => (/\d/.test(w) && /[a-z]/.test(w)) || /^\d{2,}$/.test(w) || PRODUCT_WORDS.has(w) || PRODUCT_WORDS.has(w.replace(/s$/, "")));
}

// Text that may be matched against the catalog in code: not personal and not store chrome.
export function usableTitle(text: string | undefined | null): string | null {
  const t = text ? normalizeScreenText(text) : "";
  return t && !looksPersonal(t) && !isStoreChrome(t) ? t : null;
}

// Text trusted enough to create a product, be stored with the scan, or reach a paid model, embedding or search call.
export function productTitle(text: string | undefined | null): string | null {
  const t = usableTitle(text);
  return t && hasProductSignal(t) ? t : null;
}
