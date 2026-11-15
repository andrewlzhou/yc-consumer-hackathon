import type { scoreCandidate } from "../data/catalog";

export type MatchCandidate = ReturnType<typeof scoreCandidate>;

export type HybridCandidate = MatchCandidate & { vectorScore: number | null };

// Measured on the deployment (2026-11-15): OCR-mangled titles of the right product score 0.64-0.79, while
// wrong look-alikes reach 0.52 (WH-1000XM4 -> Bose) and 0.65 (AirPods Pro 2 -> Pro 3).
const VECTOR_VIABLE = 0.6;

// OCR swaps 0/o and 1/l/i; compare letters only so "B0SE" still names Bose.
const ocrLetters = (s: string) => s.toLowerCase().replace(/0/g, "o").replace(/[1|]/g, "l").replace(/[^a-z]/g, "");
export function mentionsBrand(title: string, brand: string): boolean {
  const b = ocrLetters(brand).replace(/i/g, "l");
  return b.length > 0 && ocrLetters(title).replace(/i/g, "l").includes(b);
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
