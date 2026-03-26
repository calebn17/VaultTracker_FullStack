import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { DashboardResponse } from "@/types/api";

export function useDashboard() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/v1/dashboard"),
  });
}
