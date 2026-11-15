// Provider-neutral shapes for one model turn, so the loop can run on OpenAI or the deterministic fake.
export type JsonSchema = Record<string, unknown>;

export type ToolSpec = {
  name: string;
  description: string;
  parameters: JsonSchema;
};

export type ToolCall = { id: string; name: string; arguments: string };

export type ConversationItem =
  | { kind: "user"; text: string }
  | { kind: "assistant"; text: string }
  | { kind: "toolCalls"; calls: ToolCall[]; raw?: unknown[] }
  | { kind: "toolResult"; callId: string; output: string };

export type TurnRequest = {
  model: string;
  reasoning?: "none" | "minimal" | "low" | "medium" | "high";
  system: string;
  items: ConversationItem[];
  tools: ToolSpec[];
  toolChoice?: "auto" | "none";
  output: { name: string; schema: JsonSchema };
  maxOutputTokens?: number;
  timeoutMs?: number;
};

export type TurnResult =
  | { kind: "toolCalls"; calls: ToolCall[]; raw?: unknown[]; usage: Usage }
  | { kind: "final"; text: string; usage: Usage };

export type Usage = { inputTokens: number; outputTokens: number };

export interface LlmProvider {
  name: string;
  turn(request: TurnRequest): Promise<TurnResult>;
}
