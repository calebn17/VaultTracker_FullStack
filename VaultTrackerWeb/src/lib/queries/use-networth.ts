import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import { ApiError } from "@/lib/api-client";
import type { NetWorthHistoryResponse, NetWorthPeriod } from "@/types/api";

export type UseNetWorthHistoryOptions = {
  /** When false, skips the request (e.g. household history is shown instead). */
  enabled?: boolean;
};

export function useNetWorthHistory(
  period: NetWorthPeriod = "daily",
  options?: UseNetWorthHistoryOptions
) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["networth", period],
    queryFn: () => api.get<NetWorthHistoryResponse>(`/api/v1/networth/history?period=${period}`),
    enabled,
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
    queryFn: async () => {
      try {
        return await api.get<NetWorthHistoryResponse>(
          `/api/v1/networth/history/household?period=${period}`
        );
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
