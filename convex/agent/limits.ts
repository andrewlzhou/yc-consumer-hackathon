import { HOUR, MINUTE, RateLimiter } from "@convex-dev/rate-limiter";
import { components } from "../_generated/api";

// Spend limits on the paid paths: per device, overall, and on provisional products created from unmatched scans.
export const rateLimiter = new RateLimiter(components.rateLimiter, {
  analyzePerDevice: { kind: "token bucket", rate: 20, period: MINUTE, capacity: 10 },
  analyzeGlobal: { kind: "token bucket", rate: 600, period: HOUR, capacity: 60 },
  provisionalPerDevice: { kind: "fixed window", rate: 10, period: HOUR },
});
