"use client";

import { createContext, useContext, useMemo, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { ApiClient } from "@/lib/api-client";
import { useAuth } from "@/contexts/auth-context";

function apiBaseUrl() {
  const u =
    process.env.NEXT_PUBLIC_API_URL ?? process.env.NEXT_PUBLIC_API_HOST ?? "http://localhost:8000";
  return u.replace(/\/$/, "");
}

const ApiClientContext = createContext<ApiClient | null>(null);

export function ApiClientProvider({ children }: { children: ReactNode }) {
  const { getToken, signOutUser } = useAuth();
  const router = useRouter();

  const client = useMemo(
    () =>
      new ApiClient(apiBaseUrl(), getToken, () => {
        void signOutUser();
        router.push("/login");
      }),
    [getToken, signOutUser, router]
  );

  return <ApiClientContext.Provider value={client}>{children}</ApiClientContext.Provider>;
}

export function useApiClient() {
  const ctx = useContext(ApiClientContext);
  if (!ctx) {
    throw new Error("useApiClient must be used within ApiClientProvider");
  }
  return ctx;
}
