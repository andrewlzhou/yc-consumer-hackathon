import type { ConversationItem, LlmProvider, TurnRequest, TurnResult } from "./llm";
import type { Evidence } from "./evidence";
import { heuristicAnalysis } from "./heuristic";

type Scan = { productId: string | null; retailer: string; currentPrice: number | null; originalPrice: number | null };

// The scan facts reach the fake as the same <scan> JSON block the real model reads in its prompt.
function readScan(items: ConversationItem[]): Scan | null {
  const first = items.find((i) => i.kind === "user");
  const match = first?.kind === "user" ? first.text.match(/<scan>([\s\S]*?)<\/scan>/) : null;
  return match ? (JSON.parse(match[1]) as Scan) : null;
}

// Evidence either prefetched into the prompt or returned by tool calls, keyed by tool name (newest wins).
function evidenceByTool(items: ConversationItem[]): Map<string, Evidence> {
  const found = new Map<string, Evidence>();
  const names = new Map<string, string>();
  for (const item of items) {
    if (item.kind === "user")
      for (const m of item.text.matchAll(/<evidence id="(E\d+)" tool="([a-z_]+)">([\s\S]*?)<\/evidence>/g))
        found.set(m[2], { id: m[1], tool: m[2], args: {}, result: JSON.parse(m[3]) });
    if (item.kind === "toolCalls") for (const c of item.calls) names.set(c.id, c.name);
    if (item.kind === "toolResult") {
      const parsed = JSON.parse(item.output) as { evidenceId?: string; result?: unknown };
      const name = names.get(item.callId);
      if (name && parsed.evidenceId) found.set(name, { id: parsed.evidenceId, tool: name, args: {}, result: parsed.result });
    }
  }
  return found;
}

// Deterministic stand-in for the model: it calls the standard tools once, then answers with the heuristic analyst.
export function fakeProvider(): LlmProvider {
  let counter = 0;
  return {
    name: "fake",
    async turn(request: TurnRequest): Promise<TurnResult> {
      const usage = { inputTokens: 0, outputTokens: 0 };
      const scan = readScan(request.items);
      if (!scan?.productId) throw new Error("fake provider needs a <scan> block with a productId");
      const calledTools = request.items.some((i) => i.kind === "toolCalls");
      if (request.tools.length > 0 && request.toolChoice !== "none" && !calledTools) {
        const call = (name: string, args: object) => ({ id: `fake_${++counter}`, name, arguments: JSON.stringify(args) });
        return {
          kind: "toolCalls",
          usage,
          calls: [
            call("get_price_stats", { productId: scan.productId, retailer: null, days: 365, currentPrice: scan.currentPrice, originalPrice: scan.originalPrice }),
            call("get_promo_patterns", { productId: scan.productId, retailer: null }),
            call("find_competitors", { productId: scan.productId }),
          ],
        };
      }
      const ev = evidenceByTool(request.items);
      const output = heuristicAnalysis({ productId: scan.productId, retailer: scan.retailer, stats: ev.get("get_price_stats"), promo: ev.get("get_promo_patterns"), competitors: ev.get("find_competitors") });
      const card = { verdict: output.verdict, confidence: output.confidence, reason: output.reason, reasonEvidenceIds: output.reasonEvidenceIds };
      return { kind: "final", text: JSON.stringify(request.output.name === "purchase_card" ? card : output), usage };
    },
  };
}
