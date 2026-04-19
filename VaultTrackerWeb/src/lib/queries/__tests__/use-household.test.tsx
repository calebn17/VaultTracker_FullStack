import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import { ApiError } from "@/lib/api-client";
import type { HouseholdResponse } from "@/types/api";

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
  useCreateHousehold,
  useGenerateInviteCode,
  useHousehold,
  useJoinHousehold,
  useLeaveHousehold,
} from "@/lib/queries/use-household";

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

const householdFixture: HouseholdResponse = {
  id: "hh-1",
  createdAt: "2026-01-01T00:00:00Z",
  members: [{ userId: "u1", email: "a@example.com" }],
};

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useHousehold", () => {
  it("calls GET /api/v1/households/me and returns data", async () => {
    mockGet.mockResolvedValue(householdFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useHousehold(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/households/me");
    expect(result.current.data?.id).toBe("hh-1");
    expect(queryClient.getQueryData(["household"])).toEqual(householdFixture);
  });

  it("treats 404 as not in a household (null)", async () => {
    mockGet.mockRejectedValue(new ApiError("not found", 404));
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useHousehold(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data).toBeNull();
  });
});

describe("household mutations", () => {
  it("useCreateHousehold posts and invalidates portfolio queries", async () => {
    mockPost.mockResolvedValue(householdFixture);
    const queryClient = makeQueryClient();
    const invalidateSpy = vi.spyOn(queryClient, "invalidateQueries");

    const { result } = renderHook(() => useCreateHousehold(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync();

    expect(mockPost).toHaveBeenCalledWith("/api/v1/households", {});
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["household"] });
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["networth"] });
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["fire"] });
  });

  it("useGenerateInviteCode posts empty body", async () => {
    mockPost.mockResolvedValue({ code: "ABC", expiresAt: "2026-01-02T00:00:00Z" });
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useGenerateInviteCode(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync();

    expect(mockPost).toHaveBeenCalledWith("/api/v1/households/invite-codes", {});
  });

  it("useJoinHousehold posts code and invalidates", async () => {
    mockPost.mockResolvedValue(householdFixture);
    const queryClient = makeQueryClient();
    const invalidateSpy = vi.spyOn(queryClient, "invalidateQueries");

    const { result } = renderHook(() => useJoinHousehold(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync({ code: "JOINCODE1" });

    expect(mockPost).toHaveBeenCalledWith("/api/v1/households/join", {
      code: "JOINCODE1",
    });
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["household"] });
  });

  it("useLeaveHousehold deletes membership and invalidates", async () => {
    mockDeleteFn.mockResolvedValue(undefined);
    const queryClient = makeQueryClient();
    const invalidateSpy = vi.spyOn(queryClient, "invalidateQueries");

    const { result } = renderHook(() => useLeaveHousehold(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync();

    expect(mockDeleteFn).toHaveBeenCalledWith("/api/v1/households/me/membership");
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["household"] });
  });
});
