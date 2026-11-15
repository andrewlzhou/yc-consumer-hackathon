import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval("monitor watchlist", { hours: 4 }, internal.monitoring.check.sweep, {});

// Data & retrieval: real current prices and Google price history for the demo set (convex/data/demo.ts).
crons.daily("refresh demo prices", { hourUTC: 14, minuteUTC: 0 }, internal.data.demo.refreshDaily, {});

export default crons;
