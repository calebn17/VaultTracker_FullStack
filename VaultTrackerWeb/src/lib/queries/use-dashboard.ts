import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { DashboardResponse, HouseholdDashboardResponse } from "@/types/api";

export function useDashboard() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/v1/dashboard"),
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
    queryFn: () => api.get<HouseholdDashboardResponse>("/api/v1/dashboard/household"),
    enabled,
    retry: false,
  });
}
