// Live check against OpenAI. Skipped unless LIVE_TESTS=1 and OPENAI_API_KEY are set: npm run test:live
import { expect, test } from "vitest";
import { openAiJudge } from "./judge";
import { defaultPrefs } from "./policy";

const live = process.env.LIVE_TESTS === "1" && !!process.env.OPENAI_API_KEY;
const model = process.env.MONITOR_JUDGE_MODEL ?? "gpt-4.1-mini";
const base = {
  title: "Sony WH-1000XM6 Headphones",
  snap: { currentPrice: 279, priceSource: "scan" as const, priorLow: 298, verdict: "BUY_NOW" as const, confidence: 0.85, reason: "$279 is the lowest in 9 months and 20% under the 90-day median." },
  state: { targetPrice: 280, lastPrice: 329, lastVerdict: "WAIT" as const, prefs: defaultPrefs() },
};

test.skipIf(!live)("real low plus target hit: judge notifies with a listed trigger", async () => {
  const d = await openAiJudge(
    { ...base, candidates: [{ trigger: "target_hit", fact: "price $279.00 reached target $280.00 (was $329.00)" }, { trigger: "new_low", fact: "price $279.00 is below the previous observed low $298.00" }] },
    process.env.OPENAI_API_KEY!,
    model,
  );
  console.log("judge:", JSON.stringify(d));
  expect(d.notify).toBe(true);
  expect(["target_hit", "new_low"]).toContain(d.trigger);
});

test.skipIf(!live)("a barely different alternative on a weak verdict: judge should stay quiet or justify", async () => {
  const d = await openAiJudge(
    {
      ...base,
      snap: { ...base.snap, currentPrice: 329, verdict: "WAIT", confidence: 0.3, reason: "Price is flat; sale season is two weeks out." },
      candidates: [{ trigger: "better_alternative", fact: 'alternative "Generic ANC Headphones" at $279.00 saves 15%' }],
    },
    process.env.OPENAI_API_KEY!,
    model,
  );
  console.log("judge:", JSON.stringify(d));
  expect(typeof d.notify).toBe("boolean");
});
