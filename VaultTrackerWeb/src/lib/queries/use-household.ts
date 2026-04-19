import type { QueryClient } from "@tanstack/react-query";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import { ApiError } from "@/lib/api-client";
import type {
  HouseholdInviteCodeResponse,
  HouseholdJoinRequest,
  HouseholdResponse,
} from "@/types/api";

function invalidateHouseholdPortfolio(qc: QueryClient) {
  void qc.invalidateQueries({ queryKey: ["household"] });
  void qc.invalidateQueries({ queryKey: ["dashboard"] });
  void qc.invalidateQueries({ queryKey: ["networth"] });
  void qc.invalidateQueries({ queryKey: ["fire"] });
  void qc.invalidateQueries({ queryKey: ["analytics"] });
}

export function useHousehold() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["household"],
    queryFn: async () => {
      try {
        return await api.get<HouseholdResponse>("/api/v1/households/me");
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

export function useCreateHousehold() {
  const api = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => api.post<HouseholdResponse>("/api/v1/households", {}),
    onSuccess: () => invalidateHouseholdPortfolio(queryClient),
  });
}

export function useGenerateInviteCode() {
  const api = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => api.post<HouseholdInviteCodeResponse>("/api/v1/households/invite-codes", {}),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["household"] });
    },
  });
}

export function useJoinHousehold() {
  const api = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: HouseholdJoinRequest) =>
      api.post<HouseholdResponse>("/api/v1/households/join", body),
    onSuccess: () => invalidateHouseholdPortfolio(queryClient),
  });
}

export function useLeaveHousehold() {
  const api = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => api.delete("/api/v1/households/me/membership"),
    onSuccess: () => {
      queryClient.setQueryData(["household"], null);
      invalidateHouseholdPortfolio(queryClient);
    },
  });
}
