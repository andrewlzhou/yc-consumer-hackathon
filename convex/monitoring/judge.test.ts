import { afterEach, expect, test, vi } from "vitest";
import { judge, openAiJudge, rulesJudge } from "./judge";
import { defaultPrefs } from "./policy";

const input = {
  title: "Acme",
  snap: { currentPrice: 90, priceSource: "scan" as const, verdict: "WAIT" as const, confidence: 0.8, reason: "r" },
  state: { prefs: defaultPrefs() },
  candidates: [
    { trigger: "new_low" as const, fact: "low" },
    { trigger: "target_hit" as const, fact: "target" },
  ],
};
const reply = (content: object) => new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify(content) } }] }));

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

test("rules judge prefers target hit and stays quiet without candidates", () => {
  expect(rulesJudge(input)).toMatchObject({ notify: true, trigger: "target_hit" });
  expect(rulesJudge({ ...input, candidates: [] })).toMatchObject({ notify: false });
});

test("openai judge may only pick a listed trigger", async () => {
  vi.stubGlobal("fetch", async () => reply({ notify: true, trigger: "new_low", why: "real low" }));
  expect(await openAiJudge(input, "k", "m")).toMatchObject({ notify: true, trigger: "new_low", judge: "openai" });
  vi.stubGlobal("fetch", async () => reply({ notify: true, trigger: "sale_start", why: "invented" }));
  expect(await openAiJudge(input, "k", "m")).toMatchObject({ notify: false });
  vi.stubGlobal("fetch", async () => reply({ notify: false, why: "just noise" }));
  expect(await openAiJudge(input, "k", "m")).toMatchObject({ notify: false, why: "just noise" });
});

test("a provider failure falls back to the rules judge", async () => {
  vi.stubEnv("OPENAI_API_KEY", "k");
  vi.stubGlobal("fetch", async () => new Response("no", { status: 500 }));
  expect(await judge(input)).toMatchObject({ notify: true, judge: "rules" });
});
