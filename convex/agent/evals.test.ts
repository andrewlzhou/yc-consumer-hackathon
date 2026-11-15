/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { expect, test, vi } from "vitest";
import { internal } from "../_generated/api";
import schema from "../schema";
import { modules } from "../test.setup";

type CaseFile = { now: string; cases: { id: string; extract: Record<string, unknown>; expect: { match: { familyKey: string; variant?: Record<string, string> } | null; acceptableVerdicts: string[]; maxConfidence?: number } }[] };
const file = Object.values(import.meta.glob("../../eval/cases.json", { eager: true, import: "default" }))[0] as CaseFile;
const pick = (x: Record<string, unknown>) => Object.fromEntries(Object.entries(x).filter(([k]) => ["title", "retailer", "currentPrice", "originalPrice"].includes(k)));

// The eval set on the fake provider: identification, verdicts, confidence ceilings, grounding. CI runs this;
// eval/run.mjs runs the same cases on a deployment with the real model.
test("eval set passes on the deterministic fake provider", { timeout: 60_000 }, async () => {
  vi.stubEnv("AGENT_PROVIDER", "fake");
  const t = convexTest(schema, modules);
  await t.action(internal.seed.run.all, {});
  const cases = file.cases.map((c) => ({
    id: c.id,
    extract: pick(c.extract),
    expectFamily: c.expect.match?.familyKey ?? null,
    ...(c.expect.match?.variant ? { expectVariant: c.expect.match.variant } : {}),
    acceptable: c.expect.acceptableVerdicts as ("BUY_NOW" | "WAIT" | "CONSIDER_ALTERNATIVE" | "INVESTIGATE")[],
    ...(c.expect.maxConfidence !== undefined ? { maxConfidence: c.expect.maxConfidence } : {}),
  }));
  const results = await t.action(internal.agent.evals.run, { cases, now: Date.parse(file.now), full: true });
  const failures = results.flatMap((r) => [
    ...(r.matchOk ? [] : [`${r.id}: matched ${r.matchedFamily}`]),
    ...(r.liveScore && !(r.liveScore.verdictOk && r.liveScore.confidenceOk && r.liveScore.grounded) ? [`${r.id}: live ${r.live?.verdict} ${JSON.stringify(r.liveScore)} ${r.live?.groundingIssues}`] : []),
    ...(r.fullScore && !(r.fullScore.verdictOk && r.fullScore.confidenceOk && r.fullScore.grounded) ? [`${r.id}: full ${r.full?.verdict} ${JSON.stringify(r.fullScore)} ${r.full?.groundingIssues}`] : []),
  ]);
  expect(failures).toEqual([]);
  vi.unstubAllEnvs();
});
