import { httpRouter } from "convex/server";
import { registerWatchlistRoutes } from "./watchlist/http";
import { registerAgentRoutes } from "./agent/http";

const http = httpRouter();

registerWatchlistRoutes(http);
registerAgentRoutes(http);

export default http;
