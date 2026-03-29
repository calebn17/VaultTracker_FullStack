import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { AccountCreate, AccountResponse, AccountUpdate } from "@/types/api";

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
  useAccounts,
  useCreateAccount,
  useUpdateAccount,
  useDeleteAccount,
} from "@/lib/queries/use-accounts";

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

const accountFixture: AccountResponse[] = [
  { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange", created_at: "2026-01-01T00:00:00Z" },
  { id: "acc-2", name: "Chase Checking", account_type: "bank", created_at: "2026-01-15T00:00:00Z" },
];

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useAccounts", () => {
  it("calls api.get with correct path and returns list", async () => {
    mockGet.mockResolvedValue(accountFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useAccounts(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/accounts");
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data![0].name).toBe("Coinbase");
  });
});

describe("useCreateAccount", () => {
  it("calls api.post with the correct path and body", async () => {
    mockPost.mockResolvedValue({ id: "acc-3", name: "Kraken", account_type: "cryptoExchange", created_at: "" });
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useCreateAccount(), {
      wrapper: makeWrapper(queryClient),
    });

    const newAccount: AccountCreate = { name: "Kraken", account_type: "cryptoExchange" };
    await result.current.mutateAsync(newAccount);

    expect(mockPost).toHaveBeenCalledWith("/api/v1/accounts", newAccount);
  });

  it("invalidates accounts and dashboard query keys on success", async () => {
    mockPost.mockResolvedValue({});
    const queryClient = makeQueryClient();
    const invalidateSpy = vi
      .spyOn(queryClient, "invalidateQueries")
      .mockImplementation(() => Promise.resolve());

    const { result } = renderHook(() => useCreateAccount(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync({ name: "Test Bank", account_type: "bank" });

    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["accounts"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
    });
    expect(invalidateSpy).toHaveBeenCalledTimes(2);
  });
});

describe("useUpdateAccount", () => {
  it("calls api.put with the correct interpolated path and body", async () => {
    mockPut.mockResolvedValue({});
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useUpdateAccount(), {
      wrapper: makeWrapper(queryClient),
    });

    const updateData: AccountUpdate = { name: "Coinbase Pro" };
    await result.current.mutateAsync({ id: "acc-1", data: updateData });

    expect(mockPut).toHaveBeenCalledWith("/api/v1/accounts/acc-1", updateData);
  });

  it("invalidates accounts and dashboard on success", async () => {
    mockPut.mockResolvedValue({});
    const queryClient = makeQueryClient();
    const invalidateSpy = vi
      .spyOn(queryClient, "invalidateQueries")
      .mockImplementation(() => Promise.resolve());

    const { result } = renderHook(() => useUpdateAccount(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync({ id: "acc-1", data: { name: "New Name" } });

    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["accounts"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
    });
    expect(invalidateSpy).toHaveBeenCalledTimes(2);
  });
});

describe("useDeleteAccount", () => {
  it("calls api.delete with the correct interpolated path", async () => {
    mockDeleteFn.mockResolvedValue({});
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDeleteAccount(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync("acc-1");

    expect(mockDeleteFn).toHaveBeenCalledWith("/api/v1/accounts/acc-1");
  });

  it("invalidates all 6 query keys on success", async () => {
    mockDeleteFn.mockResolvedValue({});
    const queryClient = makeQueryClient();
    const invalidateSpy = vi
      .spyOn(queryClient, "invalidateQueries")
      .mockImplementation(() => Promise.resolve());

    const { result } = renderHook(() => useDeleteAccount(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync("acc-1");

    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["accounts"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["networth"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["analytics"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["transactions"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["assets"] });
    });
    expect(invalidateSpy).toHaveBeenCalledTimes(6);
  });
});
