import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type {
  FireProfileInputForm,
  FireProfileResponse,
  FireProjectionResponse,
} from "@/types/api";

export function useFireProfile() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["fire", "profile"],
    queryFn: () => api.get<FireProfileResponse>("/api/v1/fire/profile"),
    retry: false,
  });
}

export type UseFireProjectionOptions = {
  /** When false, skips the request (e.g. until a profile exists). */
  enabled?: boolean;
};

export function useFireProjection(options?: UseFireProjectionOptions) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["fire", "projection"],
    queryFn: () => api.get<FireProjectionResponse>("/api/v1/fire/projection"),
    enabled,
    retry: false,
  });
}

export function useSaveFireProfile() {
  const api = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: FireProfileInputForm) =>
      api.put<FireProfileResponse>("/api/v1/fire/profile", body),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["fire", "profile"] });
      void queryClient.invalidateQueries({ queryKey: ["fire", "projection"] });
    },
  });
}
