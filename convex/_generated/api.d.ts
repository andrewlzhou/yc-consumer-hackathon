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
import type * as lib_contract from "../lib/contract.js";
import type * as monitoring_apns from "../monitoring/apns.js";
import type * as monitoring_apnsClient from "../monitoring/apnsClient.js";
import type * as monitoring_check from "../monitoring/check.js";
import type * as monitoring_evaluate from "../monitoring/evaluate.js";
import type * as monitoring_judge from "../monitoring/judge.js";
import type * as monitoring_policy from "../monitoring/policy.js";
import type * as monitoring_ports from "../monitoring/ports.js";
import type * as monitoring_state from "../monitoring/state.js";
import type * as watchlist_devices from "../watchlist/devices.js";
import type * as watchlist_items from "../watchlist/items.js";
import type * as watchlist_tables from "../watchlist/tables.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  crons: typeof crons;
  "lib/contract": typeof lib_contract;
  "monitoring/apns": typeof monitoring_apns;
  "monitoring/apnsClient": typeof monitoring_apnsClient;
  "monitoring/check": typeof monitoring_check;
  "monitoring/evaluate": typeof monitoring_evaluate;
  "monitoring/judge": typeof monitoring_judge;
  "monitoring/policy": typeof monitoring_policy;
  "monitoring/ports": typeof monitoring_ports;
  "monitoring/state": typeof monitoring_state;
  "watchlist/devices": typeof watchlist_devices;
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
