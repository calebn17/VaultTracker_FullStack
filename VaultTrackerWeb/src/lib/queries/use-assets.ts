import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { AssetResponse, Category } from "@/types/api";

export function useAssets(category?: Category) {
  const api = useApiClient();
  return useQuery({
    queryKey: ["assets", category ?? "all"],
    queryFn: () => {
      const params = category ? `?category=${category}` : "";
      return api.get<AssetResponse[]>(`/api/v1/assets${params}`);
    },
  });
}
