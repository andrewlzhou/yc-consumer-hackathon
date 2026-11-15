import type { ConversationItem, JsonSchema, LlmProvider, ToolSpec, Usage } from "./llm";
import { AGENT_OUTPUT_SCHEMA, parseAgentOutput, type AgentOutput } from "./output";
import { checkGrounding, EvidenceLedger, repairCitations } from "./evidence";

export type AgentTool = ToolSpec & { run: (args: Record<string, unknown>) => Promise<unknown> };

// What the model must answer with, how to parse it, and how to check its grounding against the ledger.
export type OutputSpec<T> = {
  name: string;
  schema: JsonSchema;
  parse: (text: string) => { ok: true; value: T } | { ok: false; errors: string[] };
  check: (value: T, ledger: EvidenceLedger) => { value: T; issues: string[] };
};

export const reportSpec = (competitorTools: string[]): OutputSpec<AgentOutput> => ({
  name: "purchase_analysis",
  schema: AGENT_OUTPUT_SCHEMA,
  parse: parseAgentOutput,
  check: (value, ledger) => {
    const repaired = repairCitations(value, ledger);
    return { value: repaired, issues: checkGrounding(repaired, ledger, competitorTools) };
  },
});

export type RunOptions<T> = {
  provider: LlmProvider;
  model: string;
  reasoning?: "none" | "minimal" | "low" | "medium" | "high";
  system: string;
  prompt: string;
  tools: AgentTool[];
  output: OutputSpec<T>;
  ledger?: EvidenceLedger;
  maxToolTurns?: number;
  maxRepairs?: number;
  maxOutputTokens?: number;
  deadlineMs?: number;
};

export type RunResult<T> =
  | { ok: true; output: T; ledger: EvidenceLedger; usage: Usage; turns: number; repairs: number; groundingIssues: string[] }
  | { ok: false; error: string; ledger: EvidenceLedger; usage: Usage; turns: number };

// Runs one tool-use loop: the model calls tools until it answers; the answer is schema-checked and grounding-checked,
// and problems are sent back for a bounded number of repairs.
export async function runAgent<T>(options: RunOptions<T>): Promise<RunResult<T>> {
  const ledger = options.ledger ?? new EvidenceLedger();
  const items: ConversationItem[] = [{ kind: "user", text: options.prompt }];
  const usage = { inputTokens: 0, outputTokens: 0 };
  const maxToolTurns = options.maxToolTurns ?? 6;
  const maxRepairs = options.maxRepairs ?? 1;
  const started = Date.now();
  let toolTurns = 0;
  let repairs = 0;
  let turns = 0;
  for (;;) {
    turns++;
    const remaining = options.deadlineMs ? options.deadlineMs - (Date.now() - started) : undefined;
    let result;
    try {
      result = await options.provider.turn({
        model: options.model,
        reasoning: options.reasoning,
        system: options.system,
        items,
        tools: options.tools,
        toolChoice: toolTurns >= maxToolTurns ? "none" : "auto",
        output: { name: options.output.name, schema: options.output.schema },
        maxOutputTokens: options.maxOutputTokens,
        timeoutMs: remaining,
      });
    } catch (error) {
      return { ok: false, error: String(error), ledger, usage, turns };
    }
    usage.inputTokens += result.usage.inputTokens;
    usage.outputTokens += result.usage.outputTokens;
    if (result.kind === "toolCalls") {
      toolTurns++;
      items.push({ kind: "toolCalls", calls: result.calls, raw: result.raw });
      const outputs = await Promise.all(result.calls.map((call) => executeCall(options.tools, ledger, call.name, call.arguments)));
      result.calls.forEach((call, i) => items.push({ kind: "toolResult", callId: call.id, output: outputs[i] }));
      continue;
    }
    const parsed = options.output.parse(result.text);
    const checked = parsed.ok ? options.output.check(parsed.value, ledger) : null;
    const issues = checked ? checked.issues : parsed.ok ? [] : parsed.errors;
    const outOfTime = options.deadlineMs !== undefined && Date.now() - started > options.deadlineMs * 0.6;
    if (issues.length === 0 || repairs >= maxRepairs || outOfTime) {
      if (!checked) return { ok: false, error: `invalid output: ${issues.join("; ")}`, ledger, usage, turns };
      return { ok: true, output: checked.value, ledger, usage, turns, repairs, groundingIssues: issues };
    }
    repairs++;
    items.push({ kind: "assistant", text: result.text });
    items.push({ kind: "user", text: `Your answer failed validation. Fix these problems and answer again (call tools or the calculate tool if you need numbers):\n- ${issues.join("\n- ")}` });
  }
}

async function executeCall(tools: AgentTool[], ledger: EvidenceLedger, name: string, rawArgs: string): Promise<string> {
  const tool = tools.find((t) => t.name === name);
  if (!tool) return JSON.stringify({ error: `unknown tool ${name}` });
  let args: Record<string, unknown>;
  try {
    args = JSON.parse(rawArgs) as Record<string, unknown>;
  } catch {
    return JSON.stringify({ error: "arguments were not valid JSON" });
  }
  try {
    const result = await tool.run(args);
    const evidence = ledger.add(name, args, result);
    return JSON.stringify({ evidenceId: evidence.id, result });
  } catch (error) {
    return JSON.stringify({ error: String(error) });
  }
}
