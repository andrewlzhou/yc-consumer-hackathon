import type { scoreCandidate } from "../data/catalog";

export type MatchCandidate = ReturnType<typeof scoreCandidate>;

export type HybridCandidate = MatchCandidate & { vectorScore: number | null };

const VECTOR_VIABLE = 0.5;

// After an unclear text match: hybrid candidates without a size conflict that either share enough tokens or are
// semantically close (OCR-mangled titles), for the model to choose from.
export function hybridViable(candidates: HybridCandidate[]): HybridCandidate[] {
  return candidates.filter((c) => !c.sizeConflict && (c.score >= VIABLE_SCORE || (c.vectorScore ?? 0) >= VECTOR_VIABLE)).slice(0, 5);
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
