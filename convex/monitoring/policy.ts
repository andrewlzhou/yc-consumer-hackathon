// Pure monitoring rules: which events are candidates and which guardrails block a notification. No I/O.

import type { ObservationSource, Verdict } from "../lib/contract";

export type { Verdict };
export type PriceSource = ObservationSource | "simulated";
export type Trigger = "target_hit" | "new_low" | "buy_now_flip" | "sale_start" | "better_alternative";

export const TRIGGERS: Trigger[] = ["target_hit", "new_low", "buy_now_flip", "sale_start", "better_alternative"];

// What the analysis (shopping agent) says about a product right now. Rewire adapters in ports.ts, not here.
export type Snapshot = {
  currentPrice: number;
  priceSource: PriceSource;
  priorLow?: number;
  verdict: Verdict;
  confidence: number;
  reason: string;
  saleStartDetected?: boolean;
  // True when the verdict or alternative may rest on seeded evidence (agent's isSampleData, or seed rows in the window).
  isSampleData?: boolean;
  // False when no agent analysis was available and verdict is only the INVESTIGATE placeholder.
  hasAnalysis?: boolean;
  alternative?: { title: string; price: number; savingsPct: number };
};

export type WatchState = {
  targetPrice?: number;
  lastPrice?: number;
  lastVerdict?: Verdict;
  prefs: Record<Trigger, boolean>;
};

export type SentRecord = { createdAt: number; price: number; trigger: Trigger; dedupeKey: string };

export type Candidate = { trigger: Trigger; fact: string };

export const GUARDRAILS = {
  cooldownMs: 24 * 60 * 60 * 1000,
  escalationDropPct: 10,
  minBuyNowConfidence: 0.6,
  minAlternativeSavingsPct: 15,
  minDropPct: 1,
  minDropDollars: 0.5,
};

export const defaultPrefs = (): Record<Trigger, boolean> => ({
  target_hit: true,
  new_low: true,
  buy_now_flip: true,
  sale_start: true,
  better_alternative: true,
});

const money = (n: number) => "$" + n.toFixed(2);

export function isMeaningfulDrop(last: number, now: number) {
  const drop = last - now;
  return drop >= Math.max(GUARDRAILS.minDropDollars, (last * GUARDRAILS.minDropPct) / 100);
}

// Facts computed in code. The judge only weighs these; it never invents one.
export function findCandidates(snap: Snapshot, state: WatchState): Candidate[] {
  const out: Candidate[] = [];
  const { lastPrice, targetPrice } = state;
  const dropped = lastPrice !== undefined && isMeaningfulDrop(lastPrice, snap.currentPrice);
  if (targetPrice !== undefined && lastPrice !== undefined && lastPrice > targetPrice && snap.currentPrice <= targetPrice) {
    out.push({ trigger: "target_hit", fact: `price ${money(snap.currentPrice)} reached target ${money(targetPrice)} (was ${money(lastPrice)})` });
  }
  if (dropped && snap.priorLow !== undefined && snap.currentPrice < snap.priorLow) {
    out.push({ trigger: "new_low", fact: `price ${money(snap.currentPrice)} is below the previous observed low ${money(snap.priorLow)}` });
  }
  if (snap.verdict === "BUY_NOW" && snap.hasAnalysis !== false && state.lastVerdict !== undefined && state.lastVerdict !== "BUY_NOW" && snap.confidence >= GUARDRAILS.minBuyNowConfidence) {
    out.push({ trigger: "buy_now_flip", fact: `verdict changed from ${state.lastVerdict} to BUY_NOW (confidence ${snap.confidence})` });
  }
  if (snap.saleStartDetected && dropped) {
    out.push({ trigger: "sale_start", fact: `sale detected, price fell from ${money(lastPrice!)} to ${money(snap.currentPrice)}` });
  }
  if (snap.alternative && snap.alternative.savingsPct >= GUARDRAILS.minAlternativeSavingsPct && snap.verdict === "CONSIDER_ALTERNATIVE") {
    out.push({ trigger: "better_alternative", fact: `alternative "${snap.alternative.title}" at ${money(snap.alternative.price)} saves ${snap.alternative.savingsPct}%` });
  }
  return out;
}

export type Block = "seed" | "sample" | "preference" | "cooldown" | "dedupe";

const VERDICT_TRIGGERS: Trigger[] = ["buy_now_flip", "better_alternative"];

export const dedupeKey = (deviceId: string, productId: string, trigger: Trigger, price: number) =>
  `${deviceId}|${productId}|${trigger}|${Math.round(price * 100)}`;

// Guardrails in code, applied before and after the LLM judgment. First block wins.
export function checkGuardrails(args: {
  candidate: Candidate;
  snap: Snapshot;
  state: WatchState;
  sent: SentRecord[];
  key: string;
  now: number;
  allowSimulated: boolean;
}): Block | undefined {
  const { candidate, snap, state, sent, key, now } = args;
  if (snap.priceSource === "seed") return "seed";
  if (snap.priceSource === "simulated" && !args.allowSimulated) return "seed";
  if (snap.isSampleData && VERDICT_TRIGGERS.includes(candidate.trigger)) return "sample";
  if (!state.prefs[candidate.trigger]) return "preference";
  if (sent.some((s) => s.dedupeKey === key)) return "dedupe";
  const latest = sent.reduce<SentRecord | undefined>((a, s) => (!a || s.createdAt > a.createdAt ? s : a), undefined);
  if (latest && now - latest.createdAt < GUARDRAILS.cooldownMs) {
    const escalated = snap.currentPrice <= latest.price * (1 - GUARDRAILS.escalationDropPct / 100);
    if (!escalated) return "cooldown";
  }
  return undefined;
}
