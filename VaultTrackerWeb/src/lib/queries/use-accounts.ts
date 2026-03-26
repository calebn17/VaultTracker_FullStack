import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { AccountCreate, AccountResponse, AccountUpdate } from "@/types/api";

export function useAccounts() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["accounts"],
    queryFn: () => api.get<AccountResponse[]>("/api/v1/accounts"),
  });
}

export function useCreateAccount() {
  const api = useApiClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: AccountCreate) => api.post("/api/v1/accounts", data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}

export function useUpdateAccount() {
  const api = useApiClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      data,
    }: {
      id: string;
      data: AccountUpdate;
    }) => api.put(`/api/v1/accounts/${id}`, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}

export function useDeleteAccount() {
  const api = useApiClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/accounts/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}
