import type { FunctionReturnType } from "convex/server";
import type { internal } from "../_generated/api";

export type MatchCandidate = FunctionReturnType<typeof internal.data.catalog.matchProduct>[number];

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
