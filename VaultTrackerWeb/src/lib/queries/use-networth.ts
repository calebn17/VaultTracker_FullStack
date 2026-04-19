import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { NetWorthHistoryResponse, NetWorthPeriod } from "@/types/api";

export function useNetWorthHistory(period: NetWorthPeriod = "daily") {
  const api = useApiClient();
  return useQuery({
    queryKey: ["networth", period],
    queryFn: () => api.get<NetWorthHistoryResponse>(`/api/v1/networth/history?period=${period}`),
  });
}

export type UseNetWorthHistoryHouseholdOptions = {
  /** When false, skips the request (e.g. user is not in a household). */
  enabled?: boolean;
};

export function useNetWorthHistoryHousehold(
  period: NetWorthPeriod = "daily",
  options?: UseNetWorthHistoryHouseholdOptions
) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["networth", "household", period],
    queryFn: () =>
      api.get<NetWorthHistoryResponse>(`/api/v1/networth/history/household?period=${period}`),
    enabled,
    retry: false,
  });
}
