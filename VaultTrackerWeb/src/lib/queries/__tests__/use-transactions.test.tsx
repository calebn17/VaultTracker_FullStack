import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";
import type { SmartTransactionCreate, EnrichedTransaction } from "@/types/api";

// Mock the api client so no real network calls are made
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
  useTransactions,
  useCreateTransaction,
  useUpdateTransaction,
  useDeleteTransaction,
} from "@/lib/queries/use-transactions";

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

const txFixture: EnrichedTransaction[] = [
  {
    id: "tx-1",
    user_id: "u1",
    asset_id: "a1",
    account_id: "acc1",
    transaction_type: "buy",
    quantity: 0.5,
    price_per_unit: 60_000,
    total_value: 30_000,
    date: "2026-01-01T00:00:00Z",
    asset: { id: "a1", name: "Bitcoin", symbol: "BTC", category: "crypto" },
    account: { id: "acc1", name: "Coinbase", account_type: "cryptoExchange" },
  },
  {
    id: "tx-2",
    user_id: "u1",
    asset_id: "a2",
    account_id: "acc1",
    transaction_type: "buy",
    quantity: 10,
    price_per_unit: 3_000,
    total_value: 30_000,
    date: "2026-02-01T00:00:00Z",
    asset: { id: "a2", name: "Ethereum", symbol: "ETH", category: "crypto" },
    account: { id: "acc1", name: "Coinbase", account_type: "cryptoExchange" },
  },
];

const txData: SmartTransactionCreate = {
  transaction_type: "buy",
  category: "crypto",
  asset_name: "Bitcoin",
  symbol: "BTC",
  quantity: 0.1,
  price_per_unit: 60_000,
  account_name: "Coinbase",
  account_type: "cryptoExchange",
};

beforeEach(() => {
  vi.clearAllMocks();
});

describe("useTransactions", () => {
  it("calls api.get with correct path and returns list", async () => {
    mockGet.mockResolvedValue(txFixture);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useTransactions(), {
      wrapper: makeWrapper(queryClient),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(mockGet).toHaveBeenCalledWith("/api/v1/transactions");
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data![0].asset.name).toBe("Bitcoin");
    expect(result.current.data![1].asset.name).toBe("Ethereum");
  });
});

describe("useCreateTransaction", () => {
  it("calls api.post with the correct path and body", async () => {
    mockPost.mockResolvedValue({});
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useCreateTransaction(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync(txData);

    expect(mockPost).toHaveBeenCalledWith("/api/v1/transactions/smart", txData);
  });

  it("invalidates all 5 dependent query keys on success", async () => {
    mockPost.mockResolvedValue({});
    const queryClient = makeQueryClient();
    const invalidateSpy = vi
      .spyOn(queryClient, "invalidateQueries")
      .mockImplementation(() => Promise.resolve());

    const { result } = renderHook(() => useCreateTransaction(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync(txData);

    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
      expect(invalidateSpy).toHaveBeenCalledWith({
        queryKey: ["transactions"],
      });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["networth"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["analytics"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["assets"] });
    });
    expect(invalidateSpy).toHaveBeenCalledTimes(5);
  });
});

describe("useUpdateTransaction", () => {
  it("calls api.put with the correct interpolated path", async () => {
    mockPut.mockResolvedValue({});
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useUpdateTransaction(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync({ id: "txn-42", data: txData });

    expect(mockPut).toHaveBeenCalledWith(
      "/api/v1/transactions/txn-42/smart",
      txData
    );
  });

  it("invalidates all 5 dependent query keys on success", async () => {
    mockPut.mockResolvedValue({});
    const queryClient = makeQueryClient();
    const invalidateSpy = vi
      .spyOn(queryClient, "invalidateQueries")
      .mockImplementation(() => Promise.resolve());

    const { result } = renderHook(() => useUpdateTransaction(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync({ id: "txn-42", data: txData });

    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
      expect(invalidateSpy).toHaveBeenCalledWith({
        queryKey: ["transactions"],
      });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["networth"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["analytics"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["assets"] });
    });
    expect(invalidateSpy).toHaveBeenCalledTimes(5);
  });
});

describe("useDeleteTransaction", () => {
  it("calls api.delete with the correct interpolated path", async () => {
    mockDeleteFn.mockResolvedValue({});
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDeleteTransaction(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync("txn-99");

    expect(mockDeleteFn).toHaveBeenCalledWith("/api/v1/transactions/txn-99");
  });

  it("invalidates all 5 dependent query keys on success", async () => {
    mockDeleteFn.mockResolvedValue({});
    const queryClient = makeQueryClient();
    const invalidateSpy = vi
      .spyOn(queryClient, "invalidateQueries")
      .mockImplementation(() => Promise.resolve());

    const { result } = renderHook(() => useDeleteTransaction(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync("txn-99");

    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["dashboard"] });
      expect(invalidateSpy).toHaveBeenCalledWith({
        queryKey: ["transactions"],
      });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["networth"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["analytics"] });
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ["assets"] });
    });
    expect(invalidateSpy).toHaveBeenCalledTimes(5);
  });
});
