import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import { ApiError } from "@/lib/api-client";
import type { FireProfileResponse, FireProjectionResponse } from "@/types/api";

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

import {
  useFireProfile,
  useFireProjection,
  useHouseholdFireProfile,
  useSaveFireProfile,
  useUpdateHouseholdFire,
} from "@/lib/queries/use-fire";

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

const profileFixture: FireProfileResponse = {
  id: "p1",
  currentAge: 35,
  annualIncome: 120_000,
  annualExpenses: 55_000,
  targetRetirementAge: 55,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
};

const projectionFixture: FireProjectionResponse = {
  status: "beyond_horizon",
  unreachableReason: null,
  inputs: {
    currentAge: 35,
    annualIncome: 120_000,
    annualExpenses: 55_000,
    currentNetWorth: 0,
    targetRetirementAge: 55,
  },
  allocation: null,
  blendedReturn: 0.07,
  realBlendedReturn: 0.04,
  inflationRate: 0.03,
  annualSavings: 65_000,
  savingsRate: 65_000 / 120_000,
  fireTargets: {
    leanFire: { targetAmount: 962_500, yearsToTarget: null, targetAge: null },
    fire: { targetAmount: 1_375_000, yearsToTarget: null, targetAge: null },
    fatFire: { targetAmount: 2_062_500, yearsToTarget: null, targetAge: null },
  },
  projectionCurve: [{ age: 35, year: 2026, projectedValue: 0 }],
  monthlyBreakdown: { monthlySurplus: 65_000 / 12, monthsToFire: null },
  goalAssessment: null,
};

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useFireProfile", () => {
  it("calls api.get with /api/v1/fire/profile and returns data", async () => {
    mockGet.mockResolvedValue(profileFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useFireProfile(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/fire/profile");
    expect(result.current.data?.currentAge).toBe(35);
  });

  it("treats 404 as no profile (null data)", async () => {
    mockGet.mockRejectedValue(new ApiError("not found", 404));
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useFireProfile(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data).toBeNull();
  });
});

describe("useFireProjection", () => {
  it("calls api.get with /api/v1/fire/projection when enabled", async () => {
    mockGet.mockResolvedValue(projectionFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useFireProjection(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/fire/projection");
    expect(result.current.data?.status).toBe("beyond_horizon");
  });

  it("does not fetch when enabled is false", async () => {
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useFireProjection({ enabled: false }), {
      wrapper: makeWrapper(queryClient),
    });

    expect(result.current.fetchStatus).toBe("idle");
    expect(mockGet).not.toHaveBeenCalled();
  });
});

describe("useSaveFireProfile", () => {
  it("PUTs body and invalidates fire profile and projection queries", async () => {
    mockPut.mockResolvedValue(profileFixture);
    const queryClient = makeQueryClient();
    const invalidateSpy = vi.spyOn(queryClient, "invalidateQueries");

    const { result } = renderHook(() => useSaveFireProfile(), {
      wrapper: makeWrapper(queryClient),
    });

    const payload = {
      currentAge: 36,
      annualIncome: 125_000,
      annualExpenses: 55_000,
      targetRetirementAge: 56 as number | null,
    };

    await result.current.mutateAsync(payload);

    expect(mockPut).toHaveBeenCalledWith("/api/v1/fire/profile", payload);
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["fire", "profile"] });
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["fire", "projection"] });
  });
});

describe("useHouseholdFireProfile", () => {
  it("GETs /api/v1/households/me/fire-profile", async () => {
    mockGet.mockResolvedValue(profileFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useHouseholdFireProfile(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/households/me/fire-profile");
    expect(result.current.data?.currentAge).toBe(35);
  });

  it("treats 404 as null when not in household", async () => {
    mockGet.mockRejectedValue(new ApiError("not found", 404));
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useHouseholdFireProfile(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data).toBeNull();
  });
});

describe("useUpdateHouseholdFire", () => {
  it("PUTs /api/v1/households/me/fire-profile and invalidates household profile key", async () => {
    mockPut.mockResolvedValue(profileFixture);
    const queryClient = makeQueryClient();
    const invalidateSpy = vi.spyOn(queryClient, "invalidateQueries");

    const { result } = renderHook(() => useUpdateHouseholdFire(), {
      wrapper: makeWrapper(queryClient),
    });

    const payload = {
      currentAge: 36,
      annualIncome: 125_000,
      annualExpenses: 55_000,
      targetRetirementAge: 56 as number | null,
    };

    await result.current.mutateAsync(payload);

    expect(mockPut).toHaveBeenCalledWith("/api/v1/households/me/fire-profile", payload);
    expect(invalidateSpy).toHaveBeenCalledWith({
      queryKey: ["fire", "household"],
    });
  });
});
