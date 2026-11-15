# Not Yet: notes for coding agents (Codex, Claude Code, Capy)

Shopping app: the user screenshots a product, we say Buy now / Wait (until a date) / Fake deal,
and where to buy. Backend is Convex (TypeScript) in `convex/`. iOS app is SwiftUI in `ios/`.

## Rules
- Code decides, the model explains. All verdict math lives in `convex/verdict.ts`. Model calls
  (`convex/openai.ts`) identify products, find listings and write copy. Never let a model pick the verdict.
- Don't change the JSON the app reads (GET /scan `result`, /history rows, /discover rows) except by
  ADDING optional fields. The Swift models in `ios/App/Models.swift` must keep decoding.
- New backend work goes in new files where possible. Touch `agent.ts` and `http.ts` only where needed.
- Keep functions small and typed. No new npm dependencies unless asked.
- Env vars: OPENAI_API_KEY, OPENAI_MODEL, OPENAI_FAST_MODEL (+ any new ones you document in README).

## Test
- `npx convex dev` must deploy without type errors.
- POST /scan with a JPEG body and header `x-scan-key: test1`, then GET /scan?key=test1 until status is "done".
- POST /ask with {"q": "AirPods Pro 3"}.
