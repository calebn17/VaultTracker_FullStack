import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { DashboardResponse, HouseholdDashboardResponse } from "@/types/api";

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

import { ApiError } from "@/lib/api-client";
import { useDashboard, useDashboardHousehold } from "@/lib/queries/use-dashboard";

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

const householdDashboardFixture: HouseholdDashboardResponse = {
  householdId: "hh-1",
  totalNetWorth: 200_000,
  categoryTotals: {
    crypto: 80_000,
    stocks: 60_000,
    cash: 20_000,
    realEstate: 30_000,
    retirement: 10_000,
  },
  members: [
    {
      userId: "u1",
      email: "a@example.com",
      totalNetWorth: 100_000,
      categoryTotals: {
        crypto: 40_000,
        stocks: 30_000,
        cash: 10_000,
        realEstate: 15_000,
        retirement: 5_000,
      },
      groupedHoldings: { crypto: [], stocks: [], cash: [], realEstate: [], retirement: [] },
    },
  ],
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

  it("does not fetch when enabled is false", () => {
    mockGet.mockResolvedValue(dashboardFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDashboard({ enabled: false }), {
      wrapper: makeWrapper(queryClient),
    });

    expect(result.current.fetchStatus).toBe("idle");
    expect(mockGet).not.toHaveBeenCalled();
  });
});

describe("useDashboardHousehold", () => {
  it("calls GET /api/v1/dashboard/household when enabled", async () => {
    mockGet.mockResolvedValue(householdDashboardFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDashboardHousehold(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/dashboard/household");
    expect(result.current.data?.householdId).toBe("hh-1");
  });

  it("does not fetch when enabled is false", () => {
    mockGet.mockResolvedValue(householdDashboardFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDashboardHousehold({ enabled: false }), {
      wrapper: makeWrapper(queryClient),
    });

    expect(result.current.fetchStatus).toBe("idle");
    expect(mockGet).not.toHaveBeenCalled();
  });

  it("treats 404 as null when user has no household", async () => {
    mockGet.mockRejectedValue(new ApiError("not found", 404));
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDashboardHousehold(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data).toBeNull();
  });
});
