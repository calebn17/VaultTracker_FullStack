import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { PriceRefreshResponse, SinglePriceResponse } from "@/types/api";

export function useRefreshPrices() {
  const api = useApiClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => api.post<PriceRefreshResponse>("/api/v1/prices/refresh", {}),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
    },
  });
}

export function usePriceLookup(symbol: string) {
  const api = useApiClient();
  return useQuery({
    queryKey: ["price", symbol.toUpperCase()],
    queryFn: () =>
      api.get<SinglePriceResponse>(`/api/v1/prices/${encodeURIComponent(symbol.trim())}`),
    enabled: symbol.trim().length > 0,
  });
}
