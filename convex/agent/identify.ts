import type { scoreCandidate } from "../data/catalog";
import type { ParsedUrl } from "../data/sources/stores/url";

export type MatchCandidate = ReturnType<typeof scoreCandidate>;

export type HybridCandidate = MatchCandidate & { vectorScore: number | null };

// Store codes that name one color (AE 1114_7364_914, Nike FD2722-001). A product is that link's variant only when its
// model is the same code or its title carries the code (a product created for that link); otherwise another color's
// history would be shown for the link and the scan price recorded on it.
const COLOR_CODED_STORES = new Set(["ae", "nike"]);
export function otherVariant(product: { model?: string; title: string }, parsed: ParsedUrl | null): boolean {
  const code = parsed?.productCode?.toUpperCase();
  if (!code || !COLOR_CODED_STORES.has(parsed!.retailer)) return false;
  return product.model?.toUpperCase() !== code && !product.title.toUpperCase().includes(code);
}

// The name for a product created from a color-coded link: the title plus the link's code, kept apart from other colors.
export function variantTitle(title: string, parsed: ParsedUrl | null): string {
  return otherVariant({ title }, parsed) ? `${title} ${parsed!.productCode}` : title;
}

// Measured on the deployment (2026-11-15): OCR-mangled titles of the right product score 0.64-0.79, while
// wrong look-alikes reach 0.52 (WH-1000XM4 -> Bose) and 0.65 (AirPods Pro 2 -> Pro 3).
const VECTOR_VIABLE = 0.6;

// OCR swaps 0/o and 1/l/i; compare letters only so "B0SE" still names Bose.
const ocrLetters = (s: string) => s.toLowerCase().replace(/0/g, "o").replace(/[1|]/g, "l").replace(/[^a-z]/g, "");
export function mentionsBrand(title: string, brand: string): boolean {
  const b = ocrLetters(brand).replace(/i/g, "l");
  return b.length > 0 && ocrLetters(title).replace(/i/g, "l").includes(b);
}

// Screen text must name the matched product's brand or full model, so a partial name ("AirPods", "Pro 3") is not enough.
// A product created from a link whose page gave no brand keeps the clear-match bar alone.
export function namesProduct(text: string, product: { brand: string; model?: string }): boolean {
  if (product.brand === "unknown") return true;
  const alnum = (s: string) => s.toUpperCase().replace(/[^A-Z0-9]/g, "");
  const model = product.model ? alnum(product.model) : "";
  return mentionsBrand(text, product.brand) || (model.length >= 4 && alnum(text).includes(model));
}

// After an unclear text match: hybrid candidates without a size conflict that either share enough tokens, or are
// semantically close (OCR-mangled titles) and name the same brand, for the model to choose from.
export function hybridViable(candidates: HybridCandidate[], title: string): HybridCandidate[] {
  return candidates
    .filter((c) => !c.sizeConflict && (c.score >= VIABLE_SCORE || ((c.vectorScore ?? 0) >= VECTOR_VIABLE && mentionsBrand(title, c.product.brand))))
    .slice(0, 5);
}

export type MatchDecision =
  | { kind: "match"; candidate: MatchCandidate }
  | { kind: "ambiguous"; candidates: MatchCandidate[] }
  | { kind: "none" };

const MATCH_SCORE = 0.75;
const VIABLE_SCORE = 0.45;
const MARGIN = 0.15;

// Code decides the clear cases from the data thread's re-ranked candidates (token share, size conflicts);
// close calls go to the model. A storage or size conflict rules a candidate out.
export function decideMatch(candidates: MatchCandidate[]): MatchDecision {
  const viable = candidates.filter((c) => !c.sizeConflict && c.score >= VIABLE_SCORE);
  if (!viable.length) return { kind: "none" };
  const [top, second] = viable;
  if (top.score >= MATCH_SCORE && (!second || top.score - second.score >= MARGIN)) return { kind: "match", candidate: top };
  return { kind: "ambiguous", candidates: viable.slice(0, 5) };
}
