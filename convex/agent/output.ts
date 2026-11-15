import type { JsonSchema } from "./llm";
import { VERDICTS, type Verdict } from "../lib/contract";

export type { Verdict };

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

// The live pass answers with just the phone card, so the fast model writes ~60 tokens instead of a full report.
export type AgentCard = Pick<AgentOutput, "verdict" | "confidence" | "reason" | "reasonEvidenceIds">;
export const CARD_SCHEMA: JsonSchema = obj({
  verdict: { type: "string", enum: [...VERDICTS] },
  confidence: num,
  reason: str,
  reasonEvidenceIds: ids,
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

type Parsed<T> = { ok: true; value: T } | { ok: false; errors: string[] };

function parseWith<T>(schema: JsonSchema, text: string, confidences: (value: T) => [string, number][]): Parsed<T> {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    return { ok: false, errors: ["output is not valid JSON"] };
  }
  const errors = validateSchema(schema, value);
  if (errors.length > 0) return { ok: false, errors };
  for (const [field, c] of confidences(value as T)) if (c < 0 || c > 1) errors.push(`${field} must be between 0 and 1`);
  return errors.length > 0 ? { ok: false, errors } : { ok: true, value: value as T };
}

export const parseAgentOutput = (text: string) =>
  parseWith<AgentOutput>(AGENT_OUTPUT_SCHEMA, text, (o) => [["confidence", o.confidence], ["match.confidence", o.match.confidence], ["forecast.confidence", o.forecast.confidence]]);

export const parseCard = (text: string) => parseWith<AgentCard>(CARD_SCHEMA, text, (o) => [["confidence", o.confidence]]);
