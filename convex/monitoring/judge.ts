// The "is this a meaningful opportunity?" judgment. OpenAI when a key exists, else a deterministic rules judge.
import { Candidate, Snapshot, Trigger, WatchState } from "./policy";

export type JudgeInput = { title: string; snap: Snapshot; state: WatchState; candidates: Candidate[] };
export type JudgeDecision = { notify: boolean; trigger?: Trigger; why: string; judge: "openai" | "rules" };

const PRIORITY: Trigger[] = ["target_hit", "new_low", "buy_now_flip", "sale_start", "better_alternative"];

export function rulesJudge(input: JudgeInput): JudgeDecision {
  const top = PRIORITY.find((t) => input.candidates.some((c) => c.trigger === t));
  if (!top) return { notify: false, why: "no candidate event", judge: "rules" };
  return { notify: true, trigger: top, why: input.candidates.find((c) => c.trigger === top)!.fact, judge: "rules" };
}

const SYSTEM = `You decide whether a shopper's phone should buzz about a watched product.
Notify only for a genuine buying opportunity: the target price was reached, a real new historical low, the verdict flipped to BUY_NOW,
a genuine sale started (not a price merely returning to normal), or a clearly better alternative. Too many notifications make people mute the app.
You only choose among the listed candidate events and never invent numbers. Answer JSON: {"notify": boolean, "trigger": one candidate trigger or null, "why": short sentence using only the given facts}.`;

export async function openAiJudge(input: JudgeInput, apiKey: string, model: string): Promise<JudgeDecision> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: SYSTEM },
        {
          role: "user",
          content: JSON.stringify({
            product: input.title,
            currentPrice: input.snap.currentPrice,
            targetPrice: input.state.targetPrice ?? null,
            verdict: input.snap.verdict,
            confidence: input.snap.confidence,
            agentReason: input.snap.reason,
            candidates: input.candidates,
          }),
        },
      ],
    }),
  });
  if (!res.ok) throw new Error(`openai judge failed: ${res.status}`);
  const body = (await res.json()) as { choices?: { message?: { content?: string } }[] };
  const parsed = JSON.parse(body.choices?.[0]?.message?.content ?? "{}") as { notify?: unknown; trigger?: unknown; why?: unknown };
  const trigger = input.candidates.find((c) => c.trigger === parsed.trigger)?.trigger;
  if (parsed.notify !== true || !trigger) return { notify: false, why: typeof parsed.why === "string" ? parsed.why : "judge declined", judge: "openai" };
  return { notify: true, trigger, why: typeof parsed.why === "string" ? parsed.why : "", judge: "openai" };
}

// Falls back to the rules judge if the LLM call fails, so a provider outage never silences monitoring.
export async function judge(input: JudgeInput): Promise<JudgeDecision> {
  const key = process.env.OPENAI_API_KEY;
  if (!key) return rulesJudge(input);
  try {
    return await openAiJudge(input, key, process.env.MONITOR_JUDGE_MODEL ?? "gpt-4.1-mini");
  } catch {
    return rulesJudge(input);
  }
}
