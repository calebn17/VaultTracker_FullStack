import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";
import type { EnrichedTransaction, SmartTransactionCreate } from "@/types/api";

export function useTransactions() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["transactions"],
    queryFn: () => api.get<EnrichedTransaction[]>("/api/v1/transactions"),
  });
}

export function useCreateTransaction() {
  const api = useApiClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: SmartTransactionCreate) => api.post("/api/v1/transactions/smart", data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}

export function useUpdateTransaction() {
  const api = useApiClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: SmartTransactionCreate }) =>
      api.put(`/api/v1/transactions/${id}/smart`, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}

export function useDeleteTransaction() {
  const api = useApiClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/transactions/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}
