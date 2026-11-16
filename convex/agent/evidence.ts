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

// Clauses split at sentence ends and contrast words, never at the decimal point of a price.
const CLAUSE_BREAK = /[;!?]|\.(?=\s|$)|(?<!\d)\.(?!\d)|\b(?:but|while|whereas|although)\b/i;
const PRICE = /\$\s?(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)/g;
const DIRECTION = "below|under|less than|cheaper than|lower than|above|over|more than|higher than";
const RELATION = new RegExp(`\\bwithin\\s+(?:about\\s+)?(\\d+(?:\\.\\d+)?)\\s?%\\s+of\\b|(\\d+(?:\\.\\d+)?)\\s?%\\s+(${DIRECTION})\\b|\\$\\s?(\\d+(?:\\.\\d+)?)\\s+(${DIRECTION})\\b|\\b(matches|ties|equals|same as)\\b`, "gi");
// "is a new low", "hits a record low": a claim about today's price. "its all-time low of $198" is a noun, not a claim.
const NEW_LOW = /(?:\b(?:is|at|hits?|hitting|reached|reaches|sets?|marks?)|['’]s)\s+(?:a\s+|an\s+)?(?:new|record|all-time)\s+low\b/i;
const NEGATED = /\b(?:not|isn't|no|never|nor)\b[^$.]{0,12}$/i;
const LOW_WORD = /\blow(?:est)?\b/i;
const pctDiff = (a: number, b: number) => (Math.abs(a - b) / b) * 100;
const round1 = (n: number) => Math.round(n * 10) / 10;

type Facts = { priceVsLowest?: string; currentPrice?: number; lowestPrice?: number };
type Relation = { kind: "within" | "percent" | "dollars" | "same"; n: number; below: boolean };

// Why one relation between $a and $b is false, or null when it holds (display rounding allowed, either percent base).
function relationProblem(r: Relation, a: number, b: number): string | null {
  const diff = pctDiff(a, b);
  const fits = (x: number, n: number) => Math.abs(x - n) <= 0.6 || Math.round(x) === n;
  if (r.kind === "within") return diff > r.n + 0.5 ? `they differ by ${round1(diff)}%` : null;
  if (r.kind === "same") return diff > 1 ? `they differ by ${round1(diff)}%` : null;
  if (r.below ? a >= b : a <= b) return "the direction is wrong";
  if (r.kind === "dollars") return fits(Math.abs(a - b), r.n) ? null : `the gap is $${round1(Math.abs(a - b))}`;
  return fits(diff, r.n) || fits(pctDiff(a, b) * (b / a), r.n) ? null : `the gap is ${round1(diff)}%`;
}

// Relationships between prices stated in text must hold: "$A is within N% of $B", "$A is N% below/above $B",
// "$A is $N above $B", "$A matches $B", and "is a new low" against key_facts. Grounding alone passes "$179 is within 3%
// of $198" because both numbers exist in evidence; this check catches the false relation itself. The subject is the
// clause's first or nearest earlier price (or a later "at $A"); a missing side that names "the low" or "it" comes
// from key_facts. A relation holds when any of those subjects satisfies it.
export function relationIssues(text: string, ledger?: EvidenceLedger): string[] {
  const issues: string[] = [];
  const facts = (ledger?.items.filter((e) => e.tool === "key_facts").at(-1)?.result ?? {}) as Facts;
  for (const clause of text.split(CLAUSE_BREAK)) {
    if (!clause) continue;
    const prices = [...clause.matchAll(PRICE)].map((m) => ({ at: m.index!, end: m.index! + m[0].length, value: Number(m[1].replace(/,/g, "")) }));
    const lowClaim = clause.match(NEW_LOW);
    if (lowClaim && facts.priceVsLowest && facts.priceVsLowest !== "below_lowest_recorded") {
      const subject = prices.find((p) => p.at < lowClaim.index!)?.value;
      if (!NEGATED.test(clause.slice(0, lowClaim.index! + lowClaim[0].search(/\s/) + 1)) && (subject === undefined || subject === facts.currentPrice))
        issues.push(`says "${clause.trim()}" but today's price is not below the lowest recorded price (${facts.priceVsLowest})`);
    }
    for (const m of clause.matchAll(RELATION)) {
      const at = m.index!;
      const after = at + m[0].length;
      if (NEGATED.test(clause.slice(0, at))) continue;
      const below = (word: string) => /below|under|less|cheaper|lower/i.test(word);
      const r: Relation = m[1] !== undefined ? { kind: "within", n: Number(m[1]), below: false }
        : m[2] !== undefined ? { kind: "percent", n: Number(m[2]), below: below(m[3]) }
        : m[4] !== undefined ? { kind: "dollars", n: Number(m[4]), below: below(m[5]) }
        : { kind: "same", n: 0, below: false };
      const next = prices.find((p) => p.at >= after);
      const b = next && !/[,;]/.test(clause.slice(after, next.at)) ? next.value : LOW_WORD.test(clause.slice(after)) ? facts.lowestPrice : undefined;
      const before = prices.filter((p) => p.end <= at && !(r.kind === "dollars" && p.at === at));
      const later = prices.find((p) => p.at >= (next?.end ?? after) && p !== next)?.value;
      const candidates = before.length ? [before[0].value, before.at(-1)!.value] : later !== undefined ? [later] : [facts.currentPrice];
      const subjects = [...new Set(candidates)].filter((x): x is number => x !== undefined);
      if (b === undefined || b <= 0 || subjects.length === 0) continue;
      const problems = subjects.map((a) => relationProblem(r, a, b));
      if (problems.every((p) => p !== null)) issues.push(`says "${m[0].trim()}" between $${subjects[0]} and $${b}, but ${problems[0]}`);
    }
  }
  return issues;
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

// When a claim's number is missing from its cited evidence but present in another tool result, cite that result.
// The number is still traceable; only the model's citation bookkeeping was off.
export function repairCitations(output: AgentOutput, ledger: EvidenceLedger): AgentOutput {
  const fix = (text: string, evidenceIds: string[]) => {
    const ids = [...evidenceIds];
    for (const n of textIsGrounded(text, ids.map((id) => ledger.get(id)).filter((e): e is Evidence => !!e))) {
      const source = ledger.items.find((e) => numbersInValue(e.result).some((k) => numberMatches(n, k)));
      if (source && !ids.includes(source.id)) ids.push(source.id);
    }
    return ids;
  };
  const forecastText = [output.forecast.explanation, output.forecast.low ?? "", output.forecast.high ?? ""].join(" ");
  return {
    ...output,
    reasonEvidenceIds: fix(output.reason, output.reasonEvidenceIds),
    priceAssessment: { ...output.priceAssessment, evidenceIds: fix(output.priceAssessment.summary, output.priceAssessment.evidenceIds) },
    discount: { ...output.discount, evidenceIds: fix(output.discount.explanation, output.discount.evidenceIds) },
    forecast: { ...output.forecast, evidenceIds: fix(forecastText, output.forecast.evidenceIds) },
    retailers: { ...output.retailers, evidenceIds: fix(output.retailers.summary, output.retailers.evidenceIds) },
    competitors: output.competitors.map((c) => ({ ...c, evidenceIds: fix(c.valueReasoning, c.evidenceIds) })),
    recommendation: { ...output.recommendation, evidenceIds: fix(output.recommendation.reasoning, output.recommendation.evidenceIds) },
  };
}

// The live card has one text field: its numbers must appear in cited evidence (citations repaired first).
export function checkCard<T extends { reason: string; reasonEvidenceIds: string[] }>(card: T, ledger: EvidenceLedger): { value: T; issues: string[] } {
  const ids = [...card.reasonEvidenceIds];
  const cited = () => ids.map((id) => ledger.get(id)).filter((e): e is Evidence => !!e);
  for (const n of textIsGrounded(card.reason, cited())) {
    const source = ledger.items.find((e) => numbersInValue(e.result).some((k) => numberMatches(n, k)));
    if (source && !ids.includes(source.id)) ids.push(source.id);
  }
  const unknown = ids.filter((id) => !ledger.get(id));
  const ungrounded = textIsGrounded(card.reason, cited());
  const issues = [
    ...(unknown.length ? [`reason: cites unknown evidence ${unknown.join(", ")}`] : []),
    ...(ungrounded.length ? [`reason: numbers ${ungrounded.join(", ")} not found in any evidence`] : []),
    ...relationIssues(card.reason, ledger).map((i) => `reason: ${i}`),
  ];
  return { value: { ...card, reasonEvidenceIds: ids.filter((id) => ledger.get(id)) }, issues };
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
    issues.push(...relationIssues(claim.text, ledger).map((i) => `${claim.field}: ${i}`));
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
