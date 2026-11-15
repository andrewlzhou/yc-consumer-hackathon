import { expect, test } from "vitest";
import { Snapshot, WatchState, checkGuardrails, dedupeKey, defaultPrefs, findCandidates } from "./policy";

const snap = (over: Partial<Snapshot> = {}): Snapshot => ({
  currentPrice: 90,
  priceSource: "scan",
  priorLow: 95,
  verdict: "WAIT",
  confidence: 0.8,
  reason: "r",
  ...over,
});
const state = (over: Partial<WatchState> = {}): WatchState => ({ lastPrice: 100, lastVerdict: "WAIT", prefs: defaultPrefs(), ...over });
const now = Date.UTC(2026, 10, 15);
const guard = (over: Partial<Parameters<typeof checkGuardrails>[0]> = {}) => {
  const s = snap();
  const candidate = findCandidates(s, state())[0];
  return checkGuardrails({ candidate, snap: s, state: state(), sent: [], key: "k", now, allowSimulated: false, ...over });
};

test("target hit needs a crossing, not just being under the target", () => {
  const crossing = findCandidates(snap({ currentPrice: 89 }), state({ targetPrice: 90 }));
  expect(crossing.map((c) => c.trigger)).toContain("target_hit");
  const alreadyUnder = findCandidates(snap({ currentPrice: 85 }), state({ targetPrice: 90, lastPrice: 88 }));
  expect(alreadyUnder.map((c) => c.trigger)).not.toContain("target_hit");
});

test("a price change below the minimum drop produces no price-based candidate", () => {
  expect(findCandidates(snap({ currentPrice: 99.8, priorLow: 99.9 }), state())).toEqual([]);
});

test("new low needs a meaningful drop that beats the prior low", () => {
  expect(findCandidates(snap(), state()).map((c) => c.trigger)).toEqual(["new_low"]);
  expect(findCandidates(snap({ priorLow: 80 }), state())).toEqual([]);
});

test("a verdict flip to BUY_NOW needs confidence, an alternative needs real savings", () => {
  expect(findCandidates(snap({ currentPrice: 100, verdict: "BUY_NOW", confidence: 0.5 }), state())).toEqual([]);
  expect(findCandidates(snap({ currentPrice: 100, verdict: "BUY_NOW" }), state()).map((c) => c.trigger)).toEqual(["buy_now_flip"]);
  const alt = { title: "Other", price: 60, savingsPct: 20 };
  expect(findCandidates(snap({ currentPrice: 100, verdict: "CONSIDER_ALTERNATIVE", alternative: alt }), state()).map((c) => c.trigger)).toEqual(["better_alternative"]);
  expect(findCandidates(snap({ currentPrice: 100, verdict: "CONSIDER_ALTERNATIVE", alternative: { ...alt, savingsPct: 5 } }), state())).toEqual([]);
});

test("seed and simulated prices never pass unless simulation is allowed", () => {
  const seed = snap({ priceSource: "seed" });
  const c = findCandidates(seed, state())[0];
  expect(checkGuardrails({ candidate: c, snap: seed, state: state(), sent: [], key: "k", now, allowSimulated: true })).toBe("seed");
  const sim = snap({ priceSource: "simulated" });
  expect(checkGuardrails({ candidate: c, snap: sim, state: state(), sent: [], key: "k", now, allowSimulated: false })).toBe("seed");
  expect(checkGuardrails({ candidate: c, snap: sim, state: state(), sent: [], key: "k", now, allowSimulated: true })).toBeUndefined();
});

test("preference, dedupe and cooldown block; a further 10% drop escalates past the cooldown", () => {
  expect(guard({ state: state({ prefs: { ...defaultPrefs(), new_low: false } }) })).toBe("preference");
  const key = dedupeKey("d", "p", "new_low", 90);
  expect(guard({ key, sent: [{ createdAt: now - 1000, price: 95, trigger: "new_low", dedupeKey: key }] })).toBe("dedupe");
  const recent = { createdAt: now - 3600_000, price: 95, trigger: "new_low" as const, dedupeKey: "other" };
  expect(guard({ sent: [recent] })).toBe("cooldown");
  expect(guard({ sent: [{ ...recent, price: 120 }] })).toBeUndefined();
  expect(guard({ sent: [{ ...recent, createdAt: now - 25 * 3600_000 }] })).toBeUndefined();
});
