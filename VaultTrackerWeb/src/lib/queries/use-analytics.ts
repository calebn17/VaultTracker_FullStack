import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { AnalyticsResponse } from "@/types/api";

export function useAnalytics() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["analytics"],
    queryFn: () => api.get<AnalyticsResponse>("/api/v1/analytics"),
  });
}
