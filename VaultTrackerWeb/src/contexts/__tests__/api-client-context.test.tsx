import { useEffect } from "react";
import { render, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { User } from "firebase/auth";
import { ApiClientProvider, useApiClient } from "../api-client-context";

const loggerMocks = vi.hoisted(() => ({
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
}));

vi.mock("@/lib/logger", () => ({
  logger: loggerMocks,
}));

const mockUseAuth = vi.hoisted(() => vi.fn());
const mockRouterPush = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: mockRouterPush, replace: vi.fn() }),
}));

vi.mock("@/contexts/auth-context", () => ({
  useAuth: () => mockUseAuth(),
}));

function authValue(overrides: {
  user: User | null;
  getToken?: () => Promise<string>;
  signOutUser?: () => Promise<void>;
}) {
  return {
    user: overrides.user,
    loading: false,
    mode: "firebase" as const,
    signInWithGoogle: vi.fn(),
    signOutUser: overrides.signOutUser ?? vi.fn().mockResolvedValue(undefined),
    getToken: overrides.getToken ?? vi.fn().mockResolvedValue("tok"),
  };
}

describe("ApiClientProvider — React Query cache", () => {
  beforeEach(() => {
    mockRouterPush.mockClear();
    loggerMocks.info.mockClear();
    loggerMocks.warn.mockClear();
    loggerMocks.error.mockClear();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("clears the query cache when user is null on mount", () => {
    const queryClient = new QueryClient();
    const clearSpy = vi.spyOn(queryClient, "clear");

    mockUseAuth.mockReturnValue(authValue({ user: null }));

    render(
      <QueryClientProvider client={queryClient}>
        <ApiClientProvider>
          <span>child</span>
        </ApiClientProvider>
      </QueryClientProvider>
    );

    expect(clearSpy).toHaveBeenCalled();
  });

  it("clears the query cache when user transitions to signed out", () => {
    const queryClient = new QueryClient();
    const clearSpy = vi.spyOn(queryClient, "clear");

    const stubUser = { uid: "u1" } as User;
    mockUseAuth.mockReturnValue(authValue({ user: stubUser }));

    const { rerender } = render(
      <QueryClientProvider client={queryClient}>
        <ApiClientProvider>
          <span>child</span>
        </ApiClientProvider>
      </QueryClientProvider>
    );

    clearSpy.mockClear();
    mockUseAuth.mockReturnValue(authValue({ user: null }));
    rerender(
      <QueryClientProvider client={queryClient}>
        <ApiClientProvider>
          <span>child</span>
        </ApiClientProvider>
      </QueryClientProvider>
    );

    expect(clearSpy).toHaveBeenCalledTimes(1);
  });

  it("clears the query cache when API reports persistent 401 (onUnauthorized)", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const queryClient = new QueryClient();
    const clearSpy = vi.spyOn(queryClient, "clear");
    const signOutUser = vi.fn().mockResolvedValue(undefined);

    mockUseAuth.mockReturnValue(
      authValue({
        user: { uid: "u1" } as User,
        signOutUser,
        getToken: vi.fn().mockResolvedValue("t"),
      })
    );

    fetchMock
      .mockResolvedValueOnce(new Response(null, { status: 401 }))
      .mockResolvedValueOnce(new Response(null, { status: 401 }));

    function Caller() {
      const client = useApiClient();
      useEffect(() => {
        void client.get("/api/v1/x").catch(() => {
          /* expected ApiError after persistent 401 */
        });
      }, [client]);
      return null;
    }

    render(
      <QueryClientProvider client={queryClient}>
        <ApiClientProvider>
          <Caller />
        </ApiClientProvider>
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(signOutUser).toHaveBeenCalled();
    });
    expect(clearSpy).toHaveBeenCalled();
    expect(mockRouterPush).toHaveBeenCalledWith("/login");
  });
});
