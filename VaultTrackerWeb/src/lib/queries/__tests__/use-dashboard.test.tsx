import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { DashboardResponse } from "@/types/api";

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

import { useDashboard } from "@/lib/queries/use-dashboard";

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

const dashboardFixture: DashboardResponse = {
  totalNetWorth: 100_000,
  categoryTotals: {
    crypto: 40_000,
    stocks: 30_000,
    cash: 10_000,
    realEstate: 15_000,
    retirement: 5_000,
  },
  groupedHoldings: { crypto: [], stocks: [], cash: [], realEstate: [], retirement: [] },
};

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useDashboard", () => {
  it("calls api.get with /api/v1/dashboard and returns data", async () => {
    mockGet.mockResolvedValue(dashboardFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDashboard(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/dashboard");
    expect(result.current.data?.totalNetWorth).toBe(100_000);
  });
});
