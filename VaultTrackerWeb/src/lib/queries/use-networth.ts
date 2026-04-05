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
