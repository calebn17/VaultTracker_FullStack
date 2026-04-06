import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { NetWorthHistoryResponse } from "@/types/api";

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

import { useNetWorthHistory } from "@/lib/queries/use-networth";

function makeWrapper(queryClient: QueryClient) {
  return function Wrapper({ children }: { children: React.ReactNode }) {
    return React.createElement(QueryClientProvider, { client: queryClient }, children);
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

const historyFixture: NetWorthHistoryResponse = {
  snapshots: [{ date: "2026-01-01", value: 99_000 }],
};

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useNetWorthHistory", () => {
  it("defaults to daily period in URL and query key", async () => {
    mockGet.mockResolvedValue(historyFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useNetWorthHistory(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/networth/history?period=daily");
    expect(result.current.data?.snapshots).toHaveLength(1);
    expect(queryClient.getQueryData(["networth", "daily"])).toEqual(historyFixture);
  });

  it("uses requested period in URL and query key", async () => {
    mockGet.mockResolvedValue(historyFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useNetWorthHistory("weekly"), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/networth/history?period=weekly");
    expect(queryClient.getQueryData(["networth", "weekly"])).toEqual(historyFixture);
  });
});
