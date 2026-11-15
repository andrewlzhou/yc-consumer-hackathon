import type { LlmProvider, TurnRequest, TurnResult, ConversationItem } from "./llm";

const RESPONSES_URL = "https://api.openai.com/v1/responses";

// Maps our conversation onto Responses API input items, replaying the model's own output items verbatim.
function toInput(items: ConversationItem[]): unknown[] {
  const input: unknown[] = [];
  for (const item of items) {
    if (item.kind === "user") input.push({ role: "user", content: item.text });
    else if (item.kind === "assistant") input.push({ role: "assistant", content: item.text });
    else if (item.kind === "toolCalls") {
      if (item.raw) input.push(...item.raw);
      else
        for (const call of item.calls)
          input.push({ type: "function_call", call_id: call.id, name: call.name, arguments: call.arguments });
    } else input.push({ type: "function_call_output", call_id: item.callId, output: item.output });
  }
  return input;
}

type ResponsesOutputItem = {
  type: string;
  call_id?: string;
  name?: string;
  arguments?: string;
  content?: { type: string; text?: string; refusal?: string }[];
};

export function openAiProvider(apiKey: string): LlmProvider {
  return {
    name: "openai",
    async turn(request: TurnRequest): Promise<TurnResult> {
      const body: Record<string, unknown> = {
        model: request.model,
        instructions: request.system,
        input: toInput(request.items),
        text: { format: { type: "json_schema", name: request.output.name, schema: request.output.schema, strict: true } },
        max_output_tokens: request.maxOutputTokens ?? 2500,
        store: false,
      };
      if (request.tools.length > 0) {
        body.tools = request.tools.map((t) => ({ type: "function", name: t.name, description: t.description, parameters: t.parameters, strict: true }));
        body.tool_choice = request.toolChoice ?? "auto";
      }
      if (request.reasoning) body.reasoning = { effort: request.reasoning };
      if (request.reasoning && request.reasoning !== "none") body.include = ["reasoning.encrypted_content"];
      const res = await fetch(RESPONSES_URL, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${apiKey}` },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(request.timeoutMs ?? 60000),
      });
      if (!res.ok) throw new Error(`OpenAI ${res.status}: ${(await res.text()).slice(0, 300)}`);
      const json = (await res.json()) as { output?: ResponsesOutputItem[]; usage?: { input_tokens?: number; output_tokens?: number } };
      const usage = { inputTokens: json.usage?.input_tokens ?? 0, outputTokens: json.usage?.output_tokens ?? 0 };
      const output = json.output ?? [];
      const calls = output.filter((o) => o.type === "function_call");
      if (calls.length > 0)
        return {
          kind: "toolCalls",
          calls: calls.map((c) => ({ id: c.call_id ?? "", name: c.name ?? "", arguments: c.arguments ?? "{}" })),
          raw: output.filter((o) => o.type === "function_call" || o.type === "reasoning"),
          usage,
        };
      const parts = output.flatMap((o) => (o.type === "message" ? (o.content ?? []) : []));
      const refusal = parts.find((p) => p.type === "refusal");
      if (refusal) throw new Error(`Model refused: ${refusal.refusal}`);
      const text = parts.filter((p) => p.type === "output_text").map((p) => p.text ?? "").join("");
      if (!text) throw new Error("OpenAI returned no output text");
      return { kind: "final", text, usage };
    },
  };
}
