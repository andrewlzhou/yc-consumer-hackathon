import { KNOWN_RETAILERS } from "../data/retailers";

// Text the phone read off a screen is untrusted: a notification banner, an account header or a store's home screen can
// arrive as the "title" when no product title was visible (iOS review H3, CON-10). Such text must never become a
// catalog product, a stored scan title, or a paid model or search call.

const PERSONAL = [
  /@/,
  /\(?\b\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}\b/,
  /^\s*(?:hello|hi|hey|welcome back|good (?:morning|afternoon|evening))\b[\s,!]/i,
  /\b(?:deliver(?:ing)?|ship(?:ping)?) to\b/i,
  /\b\d{1,5}\s+(?:[a-z]+\s+){1,3}(?:st|street|ave|avenue|rd|road|blvd|boulevard|dr|drive|ln|lane|pkwy|parkway|ct|court|pl|place|hwy|highway)\b/i,
  /\b(?:apt|apartment|suite|unit)\s*#?\s*\d+/i,
  /,\s*[A-Z]{2}\s+\d{5}\b/,
  /\b(?:now|\d{1,2}\s?(?:m|min|mins|h|hr|hrs)\s+ago|yesterday)\s+[A-Z][\w' ]{0,30}:\s/,
  /^\s*[A-Z][a-z]+(?:\s[A-Z][a-z]+)?:\s+[a-z]/,
  /\b(?:are you|can you|picking up|on my way|call me|text me|sign(?:ed)? in as|your account|your orders|order #)/i,
];

// Words a store's own screens show around a product, never a product on their own.
const CHROME = new Set("app apps home homepage shop shopping store stores online official site deals deal today cart bag search sign in account menu welcome to the com www and of for".split(" "));
const STORE_NAMES = KNOWN_RETAILERS.flatMap((r) => [r.name, r.slug, r.domain ?? "", ...r.aliases]).filter(Boolean).map((s) => s.toLowerCase()).sort((a, b) => b.length - a.length);

export function looksPersonal(text: string): boolean {
  return PERSONAL.some((re) => re.test(text));
}

// "Best Buy App", "Amazon", "Target Home": nothing left once store names and app chrome are removed.
export function isStoreChrome(text: string): boolean {
  let rest = ` ${text.toLowerCase().replace(/[^a-z0-9.]+/g, " ")} `;
  for (const name of STORE_NAMES) rest = rest.split(` ${name} `).join(" ");
  return rest.replace(/\./g, " ").split(/\s+/).filter((w) => w.length > 1 && !CHROME.has(w)).length === 0;
}

export function usableTitle(text: string | undefined | null): string | null {
  const t = text?.trim();
  return t && !looksPersonal(t) && !isStoreChrome(t) ? t : null;
}
