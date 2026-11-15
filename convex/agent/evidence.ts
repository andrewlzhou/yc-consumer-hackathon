import type { AgentOutput } from "./output";

export type Evidence = { id: string; tool: string; args: unknown; result: unknown };

// Collects every tool result under a stable id (E1, E2, ...) so claims can cite it.
export class EvidenceLedger {
  readonly items: Evidence[] = [];

  add(tool: string, args: unknown, result: unknown): Evidence {
    const item = { id: `E${this.items.length + 1}`, tool, args, result };
    this.items.push(item);
    return item;
  }

  get(id: string): Evidence | undefined {
    return this.items.find((e) => e.id === id);
  }
}

const NUMBER_IN_TEXT = /\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?/g;

export function numbersInText(text: string): number[] {
  return (text.match(NUMBER_IN_TEXT) ?? []).map((n) => Number(n.replace(/,/g, "")));
}

// Every number reachable in a tool result, including numbers inside strings such as dates and titles.
export function numbersInValue(value: unknown, into: number[] = []): number[] {
  if (typeof value === "number" && Number.isFinite(value)) into.push(value);
  else if (typeof value === "string") into.push(...numbersInText(value));
  else if (Array.isArray(value)) for (const v of value) numbersInValue(v, into);
  else if (value && typeof value === "object") for (const v of Object.values(value)) numbersInValue(v, into);
  return into;
}

// Allows display rounding ($199.99 -> $200, 23.4% -> 23%) and fractions shown as percents (0.12 -> 12%).
export function numberMatches(claimed: number, signedKnown: number): boolean {
  const known = Math.abs(signedKnown);
  if (Math.abs(claimed - known) <= Math.max(0.01, Math.abs(known) * 0.006)) return true;
  if (Math.round(known) === claimed || Math.round(known * 10) / 10 === claimed) return true;
  return Math.abs(known) <= 1 && Math.round(known * 100) === claimed;
}

export function textIsGrounded(text: string, sources: Evidence[]): number[] {
  const known = sources.flatMap((e) => numbersInValue(e.result));
  return numbersInText(text).filter((n) => !known.some((k) => numberMatches(n, k)));
}

type Claim = { field: string; text: string; evidenceIds: string[] };

function claimsOf(output: AgentOutput): Claim[] {
  return [
    { field: "reason", text: output.reason, evidenceIds: output.reasonEvidenceIds },
    { field: "priceAssessment", text: output.priceAssessment.summary, evidenceIds: output.priceAssessment.evidenceIds },
    { field: "discount", text: output.discount.explanation, evidenceIds: output.discount.evidenceIds },
    { field: "forecast", text: [output.forecast.explanation, output.forecast.low ?? "", output.forecast.high ?? ""].join(" "), evidenceIds: output.forecast.evidenceIds },
    { field: "retailers", text: output.retailers.summary, evidenceIds: output.retailers.evidenceIds },
    { field: "recommendation", text: output.recommendation.reasoning, evidenceIds: output.recommendation.evidenceIds },
    ...output.competitors.map((c, i) => ({ field: `competitors[${i}]`, text: c.valueReasoning, evidenceIds: c.evidenceIds })),
  ];
}

// Returns grounding problems: unknown citations, numbers no cited tool result contains, invented competitors.
export function checkGrounding(output: AgentOutput, ledger: EvidenceLedger, competitorTools: string[]): string[] {
  const issues: string[] = [];
  for (const claim of claimsOf(output)) {
    const cited = claim.evidenceIds.map((id) => ledger.get(id));
    const missing = claim.evidenceIds.filter((_, i) => !cited[i]);
    if (missing.length) issues.push(`${claim.field}: cites unknown evidence ${missing.join(", ")}`);
    const sources = cited.filter((e): e is Evidence => !!e);
    const hasNumbers = numbersInText(claim.text).length > 0;
    if (hasNumbers && sources.length === 0) issues.push(`${claim.field}: states numbers but cites no evidence`);
    else {
      const ungrounded = textIsGrounded(claim.text, sources);
      if (ungrounded.length) issues.push(`${claim.field}: numbers ${ungrounded.join(", ")} not found in cited evidence`);
    }
  }
  const competitorSources = ledger.items.filter((e) => competitorTools.includes(e.tool));
  for (const c of output.competitors) {
    const known = competitorSources.some((e) => JSON.stringify(e.result).includes(JSON.stringify(c.productId)));
    if (!known) issues.push(`competitor ${c.productId} does not appear in any competitor tool result`);
  }
  if (output.verdict === "CONSIDER_ALTERNATIVE" && output.competitors.length === 0)
    issues.push("CONSIDER_ALTERNATIVE requires at least one cited competitor");
  return issues;
}
