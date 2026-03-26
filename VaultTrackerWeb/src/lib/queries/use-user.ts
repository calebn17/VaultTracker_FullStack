import { useMutation } from "@tanstack/react-query";
import { useApiClient } from "@/contexts/api-client-context";

export function useDeleteUserData() {
  const api = useApiClient();
  return useMutation({
    mutationFn: () => api.delete("/api/v1/users/me/data"),
  });
}
