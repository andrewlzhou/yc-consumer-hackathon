/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as crons from "../crons.js";
import type * as data_calendar from "../data/calendar.js";
import type * as data_catalog from "../data/catalog.js";
import type * as data_digests from "../data/digests.js";
import type * as data_prices from "../data/prices.js";
import type * as data_retailers from "../data/retailers.js";
import type * as data_sources_serpapi from "../data/sources/serpapi.js";
import type * as data_stats from "../data/stats.js";
import type * as data_text from "../data/text.js";
import type * as http from "../http.js";
import type * as lib_contract from "../lib/contract.js";
import type * as monitoring_apns from "../monitoring/apns.js";
import type * as monitoring_apnsClient from "../monitoring/apnsClient.js";
import type * as monitoring_check from "../monitoring/check.js";
import type * as monitoring_evaluate from "../monitoring/evaluate.js";
import type * as monitoring_judge from "../monitoring/judge.js";
import type * as monitoring_policy from "../monitoring/policy.js";
import type * as monitoring_ports from "../monitoring/ports.js";
import type * as monitoring_simulate from "../monitoring/simulate.js";
import type * as monitoring_state from "../monitoring/state.js";
import type * as seed_catalog from "../seed/catalog.js";
import type * as seed_generate from "../seed/generate.js";
import type * as seed_run from "../seed/run.js";
import type * as seed_tracks from "../seed/tracks.js";
import type * as watchlist_devices from "../watchlist/devices.js";
import type * as watchlist_http from "../watchlist/http.js";
import type * as watchlist_inbox from "../watchlist/inbox.js";
import type * as watchlist_items from "../watchlist/items.js";
import type * as watchlist_tables from "../watchlist/tables.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  crons: typeof crons;
  "data/calendar": typeof data_calendar;
  "data/catalog": typeof data_catalog;
  "data/digests": typeof data_digests;
  "data/prices": typeof data_prices;
  "data/retailers": typeof data_retailers;
  "data/sources/serpapi": typeof data_sources_serpapi;
  "data/stats": typeof data_stats;
  "data/text": typeof data_text;
  http: typeof http;
  "lib/contract": typeof lib_contract;
  "monitoring/apns": typeof monitoring_apns;
  "monitoring/apnsClient": typeof monitoring_apnsClient;
  "monitoring/check": typeof monitoring_check;
  "monitoring/evaluate": typeof monitoring_evaluate;
  "monitoring/judge": typeof monitoring_judge;
  "monitoring/policy": typeof monitoring_policy;
  "monitoring/ports": typeof monitoring_ports;
  "monitoring/simulate": typeof monitoring_simulate;
  "monitoring/state": typeof monitoring_state;
  "seed/catalog": typeof seed_catalog;
  "seed/generate": typeof seed_generate;
  "seed/run": typeof seed_run;
  "seed/tracks": typeof seed_tracks;
  "watchlist/devices": typeof watchlist_devices;
  "watchlist/http": typeof watchlist_http;
  "watchlist/inbox": typeof watchlist_inbox;
  "watchlist/items": typeof watchlist_items;
  "watchlist/tables": typeof watchlist_tables;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
