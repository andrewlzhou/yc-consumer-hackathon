import { httpRouter } from "convex/server";
import { registerWatchlistRoutes } from "./watchlist/http";

const http = httpRouter();

registerWatchlistRoutes(http);

export default http;
