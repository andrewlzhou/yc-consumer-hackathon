import { internalAction } from "../_generated/server";
import { internal } from "../_generated/api";
import { decideMatch, hybridViable, type HybridCandidate, type MatchCandidate } from "../agent/identify";
import matchCases from "../../eval/cases-match.json";
import { hybridSearch } from "./embeddings";

type Expect = { familyKey: string; variant?: Record<string, string> } | null;
type Picked = { familyKey: string; variant?: Record<string, string> } | null;

const same = (got: Picked, want: Expect) =>
  want === null ? got === null : got !== null && got.familyKey === want.familyKey && JSON.stringify(got.variant ?? {}) === JSON.stringify(want.variant ?? {});

// Text-only vs hybrid matching on eval/cases-match.json, scored with the agent's own decision rules:
// text uses decideMatch (clear match, else the top viable candidate); hybrid takes the top hybridViable candidate;
// combined is the agent's flow: a clear text match, otherwise the top hybrid candidate.
// Needs OPENAI_API_KEY for the hybrid side (one embedding per title). npx convex run data/matchEval:run
export const run = internalAction({
  args: {},
  handler: async (ctx) => {
    type Row = { group: string; title: string; text: { pick: string | null; ok: boolean; clear: boolean }; hybrid: { pick: string | null; ok: boolean; mode: string }; combined: { pick: string | null; ok: boolean } };
    const rows: Row[] = [];
    for (const c of matchCases.cases as { group: string; title: string; expect: Expect }[]) {
      const text: MatchCandidate[] = await ctx.runQuery(internal.data.catalog.matchProduct, { title: c.title, limit: 10 });
      const decision = decideMatch(text);
      const textPick = decision.kind === "match" ? decision.candidate : decision.kind === "ambiguous" ? decision.candidates[0] : null;
      const hybrid = await hybridSearch(ctx, c.title, { limit: 10 });
      const hybridPick = hybridViable(hybrid.candidates as HybridCandidate[])[0] ?? null;
      const combinedPick = decision.kind === "match" ? decision.candidate : hybridPick;
      const pick = (x: MatchCandidate | null): Picked => (x ? { familyKey: x.product.familyKey, variant: x.product.variant } : null);
      rows.push({
        group: c.group,
        title: c.title,
        text: { pick: pick(textPick)?.familyKey ?? null, ok: same(pick(textPick), c.expect), clear: decision.kind === "match" },
        hybrid: { pick: pick(hybridPick)?.familyKey ?? null, ok: same(pick(hybridPick), c.expect), mode: hybrid.mode },
        combined: { pick: pick(combinedPick)?.familyKey ?? null, ok: same(pick(combinedPick), c.expect) },
      });
    }
    const score = (method: "text" | "hybrid" | "combined", group?: string) => {
      const set = rows.filter((r) => !group || r.group === group);
      return `${set.filter((r) => r[method].ok).length}/${set.length}`;
    };
    const groups = [...new Set(rows.map((r) => r.group))];
    return {
      summary: Object.fromEntries(["all", ...groups].map((g) => [g, { text: score("text", g === "all" ? undefined : g), hybrid: score("hybrid", g === "all" ? undefined : g), combined: score("combined", g === "all" ? undefined : g) }])),
      misses: rows.filter((r) => !r.text.ok || !r.hybrid.ok || !r.combined.ok),
    };
  },
});
