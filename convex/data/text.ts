// Title normalization shared by catalog search, matching, and seeding.

const UNIT_FIXES: [RegExp, string][] = [
  [/(\d+(?:\.\d+)?)\s*-?\s*(gb|tb)\b/g, "$1$2"],
  [/(\d+(?:\.\d+)?)\s*-?\s*(?:quarts?|qts?)\b/g, "$1qt"],
  [/(\d+(?:\.\d+)?)\s*-?\s*(?:oz|ounces?|fl\.?\s*oz)\b/g, "$1oz"],
  [/(\d+(?:\.\d+)?)\s*-?\s*(?:inch(?:es)?|in\.|")/g, "$1in"],
];

const STOP_WORDS = new Set(["the", "and", "with", "for", "new", "by", "of", "a", "in", "-", "&"]);

// Common OCR swaps: digits read inside words ("Pr0" -> "pro") and letters read inside model numbers
// ("AFl0l" -> "af101"). Both readings are kept as extra search tokens.
function ocrVariants(token: string): string[] {
  const out: string[] = [];
  const letters = token.replace(/[^a-z]/g, "").length;
  if (/[01]/.test(token) && letters >= 2 && !/[2-9]/.test(token) && !/\d{2,}/.test(token)) {
    out.push(token.replace(/0/g, "o").replace(/1/g, "l"));
  }
  if (/\d/.test(token) && /[oli]/.test(token)) {
    out.push(token.replace(/o/g, "0").replace(/[li]/g, "1"));
  }
  return out.filter((x) => x !== token);
}

export function normalizeTitle(raw: string): string {
  let s = raw.toLowerCase().replace(/[®™©]/g, " ").replace(/[‐–—]/g, "-");
  for (const [re, rep] of UNIT_FIXES) s = s.replace(re, rep);
  return s.replace(/[^a-z0-9.\- ]+/g, " ").replace(/\s+/g, " ").trim();
}

export function tokenize(raw: string): string[] {
  const out: string[] = [];
  for (const t of normalizeTitle(raw).split(" ")) {
    const token = t.replace(/^[.-]+|[.-]+$/g, "");
    if (!token || STOP_WORDS.has(token)) continue;
    out.push(token);
    if (token.includes("-")) out.push(...token.split("-").filter(Boolean), token.replace(/-/g, ""));
    out.push(...ocrVariants(token));
  }
  return [...new Set(out)];
}

// Storage/size tokens like "128gb", "4qt", "10oz" change price, so matching treats them specially.
export function sizeTokens(tokens: string[]): string[] {
  return tokens.filter((t) => /^\d+(\.\d+)?(gb|tb|qt|oz|in)$/.test(t));
}

// Model-like tokens (letters and digits) with the same shape but different digits name different models:
// 1000xm4 vs 1000xm5. True when the query carries such a token and the product only has its sibling.
export function modelConflict(queryTokens: string[], productTokens: Set<string>): boolean {
  const shape = (t: string) => t.replace(/\d+/g, "#");
  const isModel = (t: string) => /\d/.test(t) && /[a-z]/.test(t);
  const productShapes = new Set([...productTokens].filter(isModel).map(shape));
  return queryTokens.some((t) => isModel(t) && !productTokens.has(t) && productShapes.has(shape(t)));
}

// Words that name a different product when the scan has them and the catalog entry does not: a line or form
// (iPad Air vs iPad, PS5 Digital vs Disc, earbuds vs headphones) or an accessory for the product (ear pads).
const DISTINGUISHING_WORDS = ["air", "pro", "max", "mini", "plus", "ultra", "lite", "digital", "earbuds", "replacement", "pads", "cushions", "protector", "skin", "strap", "cover"];

export function variantConflict(queryTokens: string[], productTokens: Set<string>): boolean {
  return modelConflict(queryTokens, productTokens) || DISTINGUISHING_WORDS.some((w) => queryTokens.includes(w) && !productTokens.has(w));
}

export function buildSearchText(parts: (string | undefined)[]): string {
  return [...new Set(parts.filter(Boolean).flatMap((p) => tokenize(p!)))].join(" ");
}
