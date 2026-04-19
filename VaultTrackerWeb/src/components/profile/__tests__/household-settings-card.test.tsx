import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, expect, it, vi, beforeEach } from "vitest";
import React from "react";

const mockUseHousehold = vi.fn();
const mockCreate = vi.fn();
const mockJoin = vi.fn();
const mockGenerate = vi.fn();
const mockLeave = vi.fn();

vi.mock("@/lib/queries/use-household", () => ({
  useHousehold: () => mockUseHousehold(),
  useCreateHousehold: () => ({ mutate: mockCreate, isPending: false }),
  useJoinHousehold: () => ({ mutate: mockJoin, isPending: false }),
  useGenerateInviteCode: () => ({ mutate: mockGenerate, isPending: false }),
  useLeaveHousehold: () => ({ mutate: mockLeave, isPending: false }),
}));

import { HouseholdSettingsCard } from "../household-settings-card";

function renderCard() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <HouseholdSettingsCard />
    </QueryClientProvider>
  );
}

beforeEach(() => {
  vi.clearAllMocks();
  mockUseHousehold.mockReturnValue({
    data: null,
    isPending: false,
    isError: false,
    error: null,
    refetch: vi.fn(),
  });
});

describe("HouseholdSettingsCard", () => {
  it("shows loading state", () => {
    mockUseHousehold.mockReturnValue({
      data: null,
      isPending: true,
      isError: false,
      error: null,
      refetch: vi.fn(),
    });
    renderCard();
    expect(screen.getByTestId("household-loading")).toBeInTheDocument();
  });

  it("shows create and join when not in a household", () => {
    renderCard();
    expect(screen.getByTestId("household-not-in")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /create household/i })).toBeInTheDocument();
    expect(screen.getByLabelText(/invite code/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /join household/i })).toBeInTheDocument();
  });

  it("calls create mutation when Create household is clicked", async () => {
    const user = userEvent.setup();
    mockCreate.mockImplementation((_args: unknown, opts: { onSuccess?: () => void }) => {
      opts.onSuccess?.();
    });
    renderCard();
    await user.click(screen.getByRole("button", { name: /create household/i }));
    expect(mockCreate).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({ onSuccess: expect.any(Function) })
    );
  });

  it("calls join with trimmed code", async () => {
    const user = userEvent.setup();
    mockJoin.mockImplementation((_args: unknown, opts: { onSuccess?: () => void }) => {
      opts.onSuccess?.();
    });
    renderCard();
    await user.type(screen.getByLabelText(/invite code/i), "  abc12345  ");
    await user.click(screen.getByRole("button", { name: /join household/i }));
    expect(mockJoin).toHaveBeenCalledWith(
      { code: "abc12345" },
      expect.objectContaining({ onSuccess: expect.any(Function) })
    );
  });

  it("shows members and invite when household has one member", () => {
    mockUseHousehold.mockReturnValue({
      data: {
        id: "hh-1",
        createdAt: "2026-01-01T00:00:00Z",
        members: [{ userId: "u1", email: "one@test.com" }],
      },
      isPending: false,
      isError: false,
      error: null,
      refetch: vi.fn(),
    });
    renderCard();
    expect(screen.getByTestId("household-in")).toBeInTheDocument();
    expect(screen.getAllByTestId("household-member")).toHaveLength(1);
    expect(screen.getByText("one@test.com")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /generate invite code/i })).toBeInTheDocument();
    expect(screen.queryByText(/household is full/i)).not.toBeInTheDocument();
  });

  it("shows full message and hides generate when two members", () => {
    mockUseHousehold.mockReturnValue({
      data: {
        id: "hh-1",
        createdAt: "2026-01-01T00:00:00Z",
        members: [
          { userId: "u1", email: "a@test.com" },
          { userId: "u2", email: "b@test.com" },
        ],
      },
      isPending: false,
      isError: false,
      error: null,
      refetch: vi.fn(),
    });
    renderCard();
    expect(screen.getByText(/household is full/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /generate invite code/i })).not.toBeInTheDocument();
  });

  it("opens leave dialog and calls leave mutation", async () => {
    const user = userEvent.setup();
    mockUseHousehold.mockReturnValue({
      data: {
        id: "hh-1",
        createdAt: "2026-01-01T00:00:00Z",
        members: [{ userId: "u1", email: "one@test.com" }],
      },
      isPending: false,
      isError: false,
      error: null,
      refetch: vi.fn(),
    });
    mockLeave.mockImplementation((_args: unknown, opts: { onSuccess?: () => void }) => {
      opts.onSuccess?.();
    });
    renderCard();
    const leaveButtons = screen.getAllByRole("button", { name: /^leave household$/i });
    await user.click(leaveButtons[0]);
    const dialog = screen.getByRole("alertdialog");
    expect(within(dialog).getByText(/leave household\?/i)).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: /^leave household$/i }));
    expect(mockLeave).toHaveBeenCalled();
  });
});
