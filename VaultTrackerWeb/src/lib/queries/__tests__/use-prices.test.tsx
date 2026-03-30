import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { PriceRefreshResponse, SinglePriceResponse } from "@/types/api";

const mockGet = vi.fn();
const mockPost = vi.fn();
const mockPut = vi.fn();
const mockDeleteFn = vi.fn();

vi.mock("@/contexts/api-client-context", () => ({
  useApiClient: () => ({
    get: mockGet,
    post: mockPost,
    put: mockPut,
    delete: mockDeleteFn,
  }),
}));

import { useRefreshPrices, usePriceLookup } from "@/lib/queries/use-prices";

function makeWrapper(queryClient: QueryClient) {
  return function Wrapper({ children }: { children: React.ReactNode }) {
    return React.createElement(
      QueryClientProvider,
      { client: queryClient },
      children
    );
  };
}

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useRefreshPrices", () => {
  it("posts to /api/v1/prices/refresh with empty body", async () => {
    const body: PriceRefreshResponse = { updated: [], skipped: [], errors: [] };
    mockPost.mockResolvedValue(body);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useRefreshPrices(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync();

    expect(mockPost).toHaveBeenCalledWith("/api/v1/prices/refresh", {});
  });

  it("invalidates dashboard, analytics, assets, and networth on success", async () => {
    mockPost.mockResolvedValue({ updated: [], skipped: [], errors: [] });
    const queryClient = makeQueryClient();
    const invalidateSpy = vi
      .spyOn(queryClient, "invalidateQueries")
      .mockImplementation(() => Promise.resolve());

    const { result } = renderHook(() => useRefreshPrices(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync();

    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["analytics"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["assets"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["networth"] });
    });
    expect(invalidateSpy).toHaveBeenCalledTimes(4);
  });
});

describe("usePriceLookup", () => {
  it("does not fetch when symbol is empty or whitespace-only", async () => {
    const queryClient = makeQueryClient();

    const { result: empty } = renderHook(() => usePriceLookup(""), {
      wrapper: makeWrapper(queryClient),
    });
    const { result: spaces } = renderHook(() => usePriceLookup("   "), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => {
      expect(empty.current.fetchStatus).toBe("idle");
      expect(spaces.current.fetchStatus).toBe("idle");
    });

    expect(mockGet).not.toHaveBeenCalled();
  });

  it("calls api.get with encoded path and returns data", async () => {
    const price: SinglePriceResponse = { symbol: "AAPL", price: 200, source: "test" };
    mockGet.mockResolvedValue(price);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => usePriceLookup("aapl"), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/prices/aapl");
    expect(result.current.data?.price).toBe(200);
  });
});
