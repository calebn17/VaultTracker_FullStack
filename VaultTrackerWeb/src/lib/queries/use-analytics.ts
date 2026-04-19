import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import { ApiError } from "@/lib/api-client";
import type { AnalyticsResponse } from "@/types/api";

export type UseAnalyticsOptions = {
  /** When false, skips the request (e.g. household analytics is shown instead). */
  enabled?: boolean;
};

export function useAnalytics(options?: UseAnalyticsOptions) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["analytics"],
    queryFn: () => api.get<AnalyticsResponse>("/api/v1/analytics"),
    enabled,
  });
}

export type UseAnalyticsHouseholdOptions = {
  /** When false, skips the request (e.g. user is not in household view). */
  enabled?: boolean;
};

export function useAnalyticsHousehold(options?: UseAnalyticsHouseholdOptions) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["analytics", "household"],
    queryFn: async () => {
      try {
        return await api.get<AnalyticsResponse>("/api/v1/analytics/household");
      } catch (e) {
        if (e instanceof ApiError && e.status === 404) {
          return null;
        }
        throw e;
      }
    },
    enabled,
    retry: false,
  });
}
