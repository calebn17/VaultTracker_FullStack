import { render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, expect, it, vi, beforeEach } from "vitest";
import React from "react";

const mockUseHousehold = vi.fn();

vi.mock("@/lib/queries/use-household", () => ({
  useHousehold: () => mockUseHousehold(),
}));

vi.mock("@/lib/queries/use-fire", () => ({
  useFireProfile: () => ({
    isSuccess: true,
    data: null,
    isError: false,
    isPending: false,
  }),
  useHouseholdFireProfile: () => ({
    isSuccess: true,
    data: null,
    isError: false,
    isPending: false,
  }),
  useFireProjection: () => ({
    data: undefined,
    isLoading: false,
    isError: false,
    isFetching: false,
  }),
  useSaveFireProfile: () => ({
    mutateAsync: vi.fn().mockResolvedValue({}),
    isPending: false,
    error: null,
  }),
  useUpdateHouseholdFire: () => ({
    mutateAsync: vi.fn().mockResolvedValue({}),
    isPending: false,
    error: null,
  }),
}));

import FirePage from "../page";

function renderPage() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <FirePage />
    </QueryClientProvider>
  );
}

beforeEach(() => {
  mockUseHousehold.mockReturnValue({ data: null, isLoading: false });
});

describe("FirePage", () => {
  it("renders a named region and primary heading", () => {
    renderPage();
    expect(screen.getByRole("region", { name: /FIRE calculator/i })).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 1, name: /FIRE calculator/i })).toBeInTheDocument();
  });

  it("shows household banner when user is in a household", () => {
    mockUseHousehold.mockReturnValue({
      data: {
        id: "hh-1",
        createdAt: "2026-01-01T00:00:00Z",
        members: [{ userId: "u1", email: "a@test.com" }],
      },
      isLoading: false,
    });
    renderPage();
    expect(screen.getByTestId("fire-household-banner")).toBeInTheDocument();
  });
});
