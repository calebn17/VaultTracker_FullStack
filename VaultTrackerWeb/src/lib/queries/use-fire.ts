import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import { ApiError } from "@/lib/api-client";
import type {
  FireProfileInputForm,
  FireProfileResponse,
  FireProjectionResponse,
  HouseholdFireProfile,
} from "@/types/api";

export function useFireProfile() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["fire", "profile"],
    queryFn: async () => {
      try {
        return await api.get<FireProfileResponse>("/api/v1/fire/profile");
      } catch (e) {
        if (e instanceof ApiError && e.status === 404) {
          return null;
        }
        throw e;
      }
    },
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

export type UseHouseholdFireProfileOptions = {
  /** When false, skips the request (e.g. user is not in a household). */
  enabled?: boolean;
};

export function useHouseholdFireProfile(options?: UseHouseholdFireProfileOptions) {
  const api = useApiClient();
  const enabled = options?.enabled ?? true;
  return useQuery({
    queryKey: ["fire", "household", "profile"],
    queryFn: async () => {
      try {
        return await api.get<HouseholdFireProfile>("/api/v1/households/me/fire-profile");
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

export function useUpdateHouseholdFire() {
  const api = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: FireProfileInputForm) =>
      api.put<HouseholdFireProfile>("/api/v1/households/me/fire-profile", body),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["fire", "household"] });
    },
  });
}
