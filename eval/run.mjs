#!/usr/bin/env node
// Runs eval/cases.json against a Convex deployment: `node eval/run.mjs [--full [--full-model model:reasoning]] [--out file]`.
// Uses whatever deployment `npx convex run` targets (CONVEX_DEPLOY_KEY or .env.local). Never records prices.
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";

export function toEvalCases(file) {
  return file.cases.map((c) => ({
    id: c.id,
    extract: Object.fromEntries(Object.entries(c.extract).filter(([k]) => ["title", "retailer", "currentPrice", "originalPrice"].includes(k))),
    expectFamily: c.expect.match ? c.expect.match.familyKey : null,
    ...(c.expect.match?.variant ? { expectVariant: c.expect.match.variant } : {}),
    acceptable: c.expect.acceptableVerdicts,
    ...(c.expect.maxConfidence !== undefined ? { maxConfidence: c.expect.maxConfidence } : {}),
  }));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const file = JSON.parse(readFileSync(new URL("./cases.json", import.meta.url)));
  const args = { cases: toEvalCases(file), now: Date.parse(file.now), full: process.argv.includes("--full") };
  const modelAt = process.argv.indexOf("--full-model");
  if (modelAt > 0) {
    const [model, reasoning] = process.argv[modelAt + 1].split(":");
    args.fullModel = { model, reasoning: reasoning ?? "none" };
  }
  const outAt = process.argv.indexOf("--out");
  const raw = execFileSync("npx", ["convex", "run", "agent/evals:run", JSON.stringify(args)], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  const results = JSON.parse(raw.slice(raw.indexOf("[")));
  const row = (t, s) => (t ? `${t.verdict.padEnd(20)} ${s.verdictOk ? "ok " : "BAD"} c=${t.confidence.toFixed(2)}${s.confidenceOk ? "" : "!"} ${s.grounded ? "grounded" : "UNGROUNDED"} ${t.source} ${t.latencyMs}ms` : "-");
  for (const r of results) {
    console.log(`${r.id.padEnd(28)} match ${r.matchOk ? "ok " : "BAD"} | live ${row(r.live, r.liveScore)}${r.full ? " | full " + row(r.full, r.fullScore) : ""}`);
    console.log(`   live: ${r.live.reason}  [${Object.entries(r.timings).map(([k, v]) => k + " " + v).join(", ")}]`);
    if (r.full) console.log(`   full: ${r.full.reason}`);
  }
  if (outAt > 0) {
    mkdirSync(new URL("./results/", import.meta.url), { recursive: true });
    writeFileSync(process.argv[outAt + 1], JSON.stringify(results, null, 2));
  }
}
