import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { AssetResponse } from "@/types/api";

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

import { useAssets } from "@/lib/queries/use-assets";

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

const assetFixture: AssetResponse[] = [
  {
    id: "a1",
    user_id: "u1",
    name: "Bitcoin",
    symbol: "BTC",
    category: "crypto",
    quantity: 1,
    current_value: 60_000,
    last_updated: "2026-01-01T00:00:00Z",
  },
];

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useAssets", () => {
  it("calls api.get with /api/v1/assets when no category", async () => {
    mockGet.mockResolvedValue(assetFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useAssets(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/assets");
    expect(result.current.data?.[0].name).toBe("Bitcoin");
  });

  it("appends category query when provided", async () => {
    mockGet.mockResolvedValue(assetFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useAssets("crypto"), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/assets?category=crypto");
  });
});
