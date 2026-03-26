/**
 * Debug auth — `NODE_ENV` is inlined at build time so production bundles do not
 * retain the debug token or enable the bypass (see auth-context).
 */
export const DEBUG_AUTH_AVAILABLE = process.env.NODE_ENV === "development";

export const DEBUG_AUTH_TOKEN: string =
  process.env.NODE_ENV === "development" ? "vaulttracker-debug-user" : "";
