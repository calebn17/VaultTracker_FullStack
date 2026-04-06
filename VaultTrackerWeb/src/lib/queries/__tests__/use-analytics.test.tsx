import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { AnalyticsResponse } from "@/types/api";

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

import { useAnalytics } from "@/lib/queries/use-analytics";

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

const analyticsFixture: AnalyticsResponse = {
  allocation: {
    crypto: { value: 1, percentage: 50 },
    stocks: { value: 1, percentage: 50 },
    cash: { value: 0, percentage: 0 },
    realEstate: { value: 0, percentage: 0 },
    retirement: { value: 0, percentage: 0 },
  },
  performance: {
    totalGainLoss: 100,
    totalGainLossPercent: 1,
    costBasis: 99_000,
    currentValue: 100_000,
  },
};

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useAnalytics", () => {
  it("calls api.get with /api/v1/analytics and returns data", async () => {
    mockGet.mockResolvedValue(analyticsFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useAnalytics(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/analytics");
    expect(result.current.data?.performance.currentValue).toBe(100_000);
  });
});
