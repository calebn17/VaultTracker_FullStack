import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, expect, it, vi, beforeEach } from "vitest";
import React from "react";

const mockUseHousehold = vi.fn();
const mockUseDashboard = vi.fn();
const mockUseDashboardHousehold = vi.fn();
const mockUseNetWorthHistory = vi.fn();
const mockUseNetWorthHistoryHousehold = vi.fn();
const mockUseRefreshPrices = vi.fn();
const mockUseCreateTransaction = vi.fn();

vi.mock("@/lib/queries/use-household", () => ({
  useHousehold: () => mockUseHousehold(),
}));

vi.mock("@/lib/queries/use-dashboard", () => ({
  useDashboard: () => mockUseDashboard(),
  useDashboardHousehold: (opts?: { enabled?: boolean }) => mockUseDashboardHousehold(opts),
}));

vi.mock("@/lib/queries/use-networth", () => ({
  useNetWorthHistory: (period?: string) => mockUseNetWorthHistory(period),
  useNetWorthHistoryHousehold: (period?: string, opts?: { enabled?: boolean }) =>
    mockUseNetWorthHistoryHousehold(period, opts),
}));

vi.mock("@/lib/queries/use-prices", () => ({
  useRefreshPrices: () => mockUseRefreshPrices(),
}));

vi.mock("@/lib/queries/use-transactions", () => ({
  useCreateTransaction: () => mockUseCreateTransaction(),
}));

import DashboardPage from "../page";

const emptyTotals = {
  crypto: 0,
  stocks: 0,
  cash: 0,
  realEstate: 0,
  retirement: 0,
};

const emptyGrouped = {
  crypto: [],
  stocks: [],
  cash: [],
  realEstate: [],
  retirement: [],
};

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
}

function renderPage() {
  const client = makeQueryClient();
  return render(
    <QueryClientProvider client={client}>
      <DashboardPage />
    </QueryClientProvider>
  );
}

function baseHistory() {
  return {
    data: { snapshots: [{ date: "2026-01-01", value: 1000 }] },
    isLoading: false,
    isError: false,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  mockUseHousehold.mockReturnValue({ data: null, isLoading: false });
  mockUseDashboard.mockReturnValue({
    data: {
      totalNetWorth: 1000,
      categoryTotals: emptyTotals,
      groupedHoldings: emptyGrouped,
    },
    isLoading: false,
    isError: false,
    error: null,
  });
  mockUseDashboardHousehold.mockReturnValue({
    data: undefined,
    isLoading: false,
    isError: false,
    error: null,
  });
  mockUseNetWorthHistory.mockImplementation(() => baseHistory());
  mockUseNetWorthHistoryHousehold.mockImplementation(() => baseHistory());
  mockUseRefreshPrices.mockReturnValue({
    mutate: vi.fn(),
    isPending: false,
  });
  mockUseCreateTransaction.mockReturnValue({
    mutateAsync: vi.fn(),
    isPending: false,
  });
});

describe("DashboardPage household", () => {
  it("does not show scope toggle when not in a household", () => {
    renderPage();
    expect(screen.queryByRole("group", { name: /dashboard scope/i })).not.toBeInTheDocument();
    expect(screen.getByText(/total net worth/i)).toBeInTheDocument();
  });

  it("shows Household / Just me and household hero when in a household", async () => {
    const user = userEvent.setup();
    mockUseHousehold.mockReturnValue({
      data: {
        id: "hh-1",
        createdAt: "2026-01-01T00:00:00Z",
        members: [{ userId: "u1", email: "a@test.com" }],
      },
      isLoading: false,
    });
    mockUseDashboardHousehold.mockReturnValue({
      data: {
        householdId: "hh-1",
        totalNetWorth: 5000,
        categoryTotals: emptyTotals,
        members: [
          {
            userId: "u1",
            email: "a@test.com",
            totalNetWorth: 5000,
            categoryTotals: emptyTotals,
            groupedHoldings: emptyGrouped,
          },
        ],
      },
      isLoading: false,
      isError: false,
      error: null,
    });

    renderPage();

    expect(screen.getByRole("group", { name: /dashboard scope/i })).toBeInTheDocument();
    expect(screen.getByText(/household net worth/i)).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: /household members/i })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /^just me$/i }));
    expect(screen.getByText(/total net worth/i)).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: /household members/i })).not.toBeInTheDocument();
  });
});
