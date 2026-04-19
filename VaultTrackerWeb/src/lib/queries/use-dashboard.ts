import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import { ApiError } from "@/lib/api-client";
import type { DashboardResponse, HouseholdDashboardResponse } from "@/types/api";

export type UseDashboardOptions = {
  /** When false, skips the request (e.g. household merged view is active). */
  enabled?: boolean;
};

export function useDashboard(options?: UseDashboardOptions) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/v1/dashboard"),
    enabled,
  });
}

export type UseDashboardHouseholdOptions = {
  /** When false, skips the request (e.g. user is not in a household). */
  enabled?: boolean;
};

export function useDashboardHousehold(options?: UseDashboardHouseholdOptions) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["dashboard", "household"],
    queryFn: async () => {
      try {
        return await api.get<HouseholdDashboardResponse>("/api/v1/dashboard/household");
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
