import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// 7 AM Pacific. Every saved item gets a fresh price until its need-by date.
crons.daily("re-check saved items", { hourUTC: 15, minuteUTC: 0 }, internal.agent.recheckSaved, {});

export default crons;
