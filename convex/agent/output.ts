import type { JsonSchema } from "./llm";

export const VERDICTS = ["BUY_NOW", "WAIT", "CONSIDER_ALTERNATIVE", "INVESTIGATE"] as const;
export type Verdict = (typeof VERDICTS)[number];

export const DISCOUNT_STATUSES = ["genuine", "misleading", "no_discount_claimed", "unclear"] as const;
export const DISCOUNT_SIGNALS = [
  "was_price_rarely_seen",
  "price_raised_before_sale",
  "sale_price_is_normal_price",
  "small_real_savings",
] as const;

export type Cited = { evidenceIds: string[] };

export type AgentOutput = {
  match: { productId: string | null; confidence: number; note: string };
  verdict: Verdict;
  confidence: number;
  reason: string;
  reasonEvidenceIds: string[];
  priceAssessment: { summary: string } & Cited;
  discount: {
    status: (typeof DISCOUNT_STATUSES)[number];
    signals: (typeof DISCOUNT_SIGNALS)[number][];
    explanation: string;
  } & Cited;
  forecast: { low: number | null; high: number | null; byDate: string | null; confidence: number; explanation: string } & Cited;
  retailers: { summary: string } & Cited;
  competitors: ({ productId: string; title: string; valueReasoning: string } & Cited)[];
  recommendation: { reasoning: string } & Cited;
};

const str = { type: "string" };
const num = { type: "number" };
const ids = { type: "array", items: str };
const nullable = (type: string) => ({ type: [type, "null"] });
const obj = (properties: Record<string, unknown>): JsonSchema => ({
  type: "object",
  properties,
  required: Object.keys(properties),
  additionalProperties: false,
});

// One schema drives OpenAI strict structured output and our own validation of every provider's answer.
export const AGENT_OUTPUT_SCHEMA: JsonSchema = obj({
  match: obj({ productId: nullable("string"), confidence: num, note: str }),
  verdict: { type: "string", enum: [...VERDICTS] },
  confidence: num,
  reason: str,
  reasonEvidenceIds: ids,
  priceAssessment: obj({ summary: str, evidenceIds: ids }),
  discount: obj({
    status: { type: "string", enum: [...DISCOUNT_STATUSES] },
    signals: { type: "array", items: { type: "string", enum: [...DISCOUNT_SIGNALS] } },
    explanation: str,
    evidenceIds: ids,
  }),
  forecast: obj({ low: nullable("number"), high: nullable("number"), byDate: nullable("string"), confidence: num, explanation: str, evidenceIds: ids }),
  retailers: obj({ summary: str, evidenceIds: ids }),
  competitors: { type: "array", items: obj({ productId: str, title: str, valueReasoning: str, evidenceIds: ids }) },
  recommendation: obj({ reasoning: str, evidenceIds: ids }),
});

function typeOf(value: unknown): string {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

// Validates the JSON-schema subset used above: object, array, string, number, enum, nullable unions.
export function validateSchema(schema: JsonSchema, value: unknown, path = "$"): string[] {
  const types = ([] as unknown[]).concat(schema.type);
  const actual = typeOf(value);
  if (!types.includes(actual)) return [`${path}: expected ${types.join("|")}, got ${actual}`];
  if (actual === "number" && !Number.isFinite(value)) return [`${path}: not a finite number`];
  if (schema.enum && !(schema.enum as unknown[]).includes(value)) return [`${path}: ${String(value)} not allowed`];
  if (actual === "array") return (value as unknown[]).flatMap((v, i) => validateSchema(schema.items as JsonSchema, v, `${path}[${i}]`));
  if (actual !== "object") return [];
  const props = schema.properties as Record<string, JsonSchema>;
  const record = value as Record<string, unknown>;
  const errors = Object.keys(record).filter((k) => !(k in props)).map((k) => `${path}.${k}: unexpected`);
  for (const [key, sub] of Object.entries(props)) {
    if (!(key in record)) errors.push(`${path}.${key}: missing`);
    else errors.push(...validateSchema(sub, record[key], `${path}.${key}`));
  }
  return errors;
}

export function parseAgentOutput(text: string): { ok: true; value: AgentOutput } | { ok: false; errors: string[] } {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    return { ok: false, errors: ["output is not valid JSON"] };
  }
  const errors = validateSchema(AGENT_OUTPUT_SCHEMA, value);
  if (errors.length > 0) return { ok: false, errors };
  const output = value as AgentOutput;
  for (const [field, c] of [["confidence", output.confidence], ["match.confidence", output.match.confidence], ["forecast.confidence", output.forecast.confidence]] as const)
    if (c < 0 || c > 1) errors.push(`${field} must be between 0 and 1`);
  return errors.length > 0 ? { ok: false, errors } : { ok: true, value: output };
}
