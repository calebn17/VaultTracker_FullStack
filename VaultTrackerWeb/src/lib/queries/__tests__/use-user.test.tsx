import { renderHook, waitFor } from "@testing-library/react";
import {
  QueryClient,
  QueryClientProvider,
} from "@tanstack/react-query";
import { vi, describe, it, expect, beforeEach } from "vitest";
import React from "react";

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

import { useDeleteUserData } from "@/lib/queries/use-user";

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

describe("useDeleteUserData", () => {
  it("calls api.delete with /api/v1/users/me/data", async () => {
    mockDeleteFn.mockResolvedValue(undefined);
    const queryClient = makeQueryClient();

    const { result } = renderHook(() => useDeleteUserData(), {
      wrapper: makeWrapper(queryClient),
    });

    await result.current.mutateAsync();

    expect(mockDeleteFn).toHaveBeenCalledWith("/api/v1/users/me/data");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
  });
});
